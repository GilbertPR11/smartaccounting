import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/receipt/receipt_bloc.dart';
import '../../../bloc/vendor/vendor_bloc.dart';
import '../../../components/initials_avatar.dart';
import '../../../components/money_text.dart';
import '../../../components/receipt_thumb.dart';
import '../../../components/section_header.dart';
import '../../../config/constants.dart';
import '../../../exception/app_exception.dart';
import '../../../models/receipt_model.dart';
import '../../../repository/receipt_repository.dart';
import '../../../repository/setting_repository.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import '../purchase_flows.dart';

/// One receipt: the photo next to the details.
/// To review → fill in, then "Record expense" (or save for later, or turn it
/// into a bill). Done → read-only summary with where it went.
class ReceiptPage extends StatelessWidget {
  const ReceiptPage({super.key, required this.receiptId});

  final String receiptId;

  @override
  Widget build(BuildContext context) {
    final receipt = context.select<ReceiptBloc, Receipt?>((b) => b.state.byId(receiptId));
    if (receipt == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This receipt was deleted.')),
      );
    }
    return receipt.isDone
        ? _DoneReceipt(receipt: receipt)
        : _ReviewReceipt(key: ValueKey(receipt.id), receipt: receipt);
  }
}

// --------------------------------------------------------------- to review

class _ReviewReceipt extends StatefulWidget {
  const _ReviewReceipt({super.key, required this.receipt});

  final Receipt receipt;

  @override
  State<_ReviewReceipt> createState() => _ReviewReceiptState();
}

class _ReviewReceiptState extends State<_ReviewReceipt> {
  final _formKey = GlobalKey<FormState>();
  late final _merchant = TextEditingController(text: widget.receipt.merchant);
  late final _amount = TextEditingController(
      text: widget.receipt.amount == null ? '' : widget.receipt.amount!.toStringAsFixed(2));
  late final _note = TextEditingController(text: widget.receipt.note);
  late String? _vendorId = widget.receipt.vendorId;
  late DateTime _date = widget.receipt.date ?? widget.receipt.addedOn;
  late String? _category = widget.receipt.category;
  late String _account =
      widget.receipt.account ?? context.read<SettingRepository>().accounts.first;

  /// Set while waiting for the Bloc to finish an action we started.
  ReceiptAction? _pending;

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Receipt get _draft => Receipt(
        id: widget.receipt.id,
        imageBytes: widget.receipt.imageBytes,
        addedOn: widget.receipt.addedOn,
        vendorId: _vendorId,
        merchant: _vendorId == null ? _merchant.text.trim() : '',
        date: _date,
        amount: parseAmount(_amount.text),
        category: _category,
        account: _account,
        note: _note.text.trim(),
      );

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickVendor() async {
    final vendors = context.read<VendorBloc>().state.vendors;
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        builder: (ctx, controller) => ListView(
          controller: controller,
          children: [
            for (final v in vendors)
              ListTile(
                leading: InitialsAvatar(v.name),
                title: Text(v.name),
                subtitle: v.defaultCategory == null ? null : Text(v.defaultCategory!),
                onTap: () => Navigator.pop(ctx, v.id),
              ),
          ],
        ),
      ),
    );
    if (id == null || !mounted) return;
    setState(() {
      _vendorId = id;
      _category ??= context.read<VendorBloc>().state.byId(id)?.defaultCategory;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: context.read<SettingRepository>().today,
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  void _record() {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      _snack('Choose a category.');
      return;
    }
    setState(() => _pending = ReceiptAction.recorded);
    context.read<ReceiptBloc>().add(RecordReceipt(_draft));
  }

  void _saveForLater() {
    setState(() => _pending = ReceiptAction.saved);
    context.read<ReceiptBloc>().add(SaveReceiptDetails(_draft));
  }

  Future<void> _makeBill() async {
    final draft = _draft;
    try {
      await context.read<ReceiptRepository>().updateDetails(draft);
    } on AppException catch (e) {
      _snack(e.message);
      return;
    }
    if (!mounted) return;
    await openBillForm(context, receipt: draft, replace: true);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this receipt?'),
        content: const Text('The photo and anything you typed will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.ledger.moneyOut),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _pending = ReceiptAction.deleted);
    context.read<ReceiptBloc>().add(DeleteReceipt(widget.receipt.id));
  }

  void _onAction(BuildContext context, ReceiptState s) {
    final pending = _pending;
    if (pending == null || s.action == ReceiptAction.working) return;
    setState(() => _pending = null);
    if (s.action == ReceiptAction.failed) {
      _snack(s.error ?? 'Something went wrong.');
      return;
    }
    final msg = switch (s.action) {
      ReceiptAction.recorded => 'Expense recorded',
      ReceiptAction.saved => 'Saved. It stays in To review.',
      ReceiptAction.deleted => 'Receipt deleted',
      _ => null,
    };
    if (msg != null) _snack(msg);
    // Recording swaps this view for the read-only one automatically;
    // saving for later or deleting returns to the list.
    if (s.action != ReceiptAction.recorded) Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vendor = context.watch<VendorBloc>().state.byId(_vendorId);
    final accounts = context.read<SettingRepository>().accounts;
    final busy = _pending != null;
    final text = Theme.of(context).textTheme;

    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('Paid to'),
          if (vendor != null)
            Card(
              child: ListTile(
                leading: InitialsAvatar(vendor.name),
                title: Text(vendor.name),
                subtitle: const Text('Saved vendor'),
                trailing: IconButton(
                  tooltip: 'Not this vendor',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _vendorId = null),
                ),
              ),
            )
          else
            TextFormField(
              controller: _merchant,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Shop or business',
                hintText: 'e.g. Petronas Bangsar',
                suffixIcon: IconButton(
                  tooltip: 'Choose a saved vendor',
                  icon: const Icon(Icons.storefront_outlined),
                  onPressed: _pickVendor,
                ),
              ),
            ),
          const SectionHeader('Details'),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Total paid', prefixText: '${Constants.currency} '),
                  validator: (v) {
                    final n = parseAmount(v ?? '');
                    return (n == null || n <= 0) ? 'Enter the total' : null;
                  },
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(Radii.control),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                    child: Text(fmtDate(_date)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          DropdownButtonFormField<String?>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final c in Constants.expenseCategories)
                DropdownMenuItem<String?>(value: c, child: Text(c)),
            ],
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: Space.md),
          DropdownButtonFormField<String>(
            value: _account,
            decoration: const InputDecoration(labelText: 'Paid from'),
            items: [for (final a in accounts) DropdownMenuItem(value: a, child: Text(a))],
            onChanged: (v) => setState(() => _account = v ?? _account),
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _note,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          const SizedBox(height: Space.xl),
          FilledButton.icon(
            onPressed: busy ? null : _record,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Record expense'),
          ),
          const SizedBox(height: Space.sm),
          OutlinedButton(
            onPressed: busy ? null : _saveForLater,
            child: const Text('Save and finish later'),
          ),
          const SizedBox(height: Space.lg),
          Text('Not paid yet? Turn it into a bill to pay later.',
              style: text.bodySmall, textAlign: TextAlign.center),
          TextButton(onPressed: busy ? null : _makeBill, child: const Text('Create a bill instead')),
        ],
      ),
    );

    return BlocListener<ReceiptBloc, ReceiptState>(
      listenWhen: (a, b) => a.actionCount != b.actionCount,
      listener: _onAction,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review receipt'),
          actions: [
            IconButton(
              tooltip: 'Delete receipt',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: busy ? null : _delete,
            ),
            const SizedBox(width: Space.xs),
          ],
        ),
        body: _PhotoAndContent(receipt: widget.receipt, content: form),
      ),
    );
  }
}

// --------------------------------------------------------------- done

class _DoneReceipt extends StatelessWidget {
  const _DoneReceipt({required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final r = receipt;
    final vendorName = context.select<VendorBloc, String?>((b) => b.state.byId(r.vendorId)?.name);
    final l = context.ledger;
    final text = Theme.of(context).textTheme;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: Row(
            children: [
              SizedBox(width: 110, child: Text(label, style: text.bodySmall)),
              Expanded(child: Text(value, style: text.bodyMedium)),
            ],
          ),
        );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Space.lg),
        Row(
          children: [
            IconBadge(Icons.check_circle_outline_rounded, color: l.moneyIn),
            const SizedBox(width: Space.md),
            Expanded(child: Text(r.status.label, style: text.titleMedium)),
          ],
        ),
        const SizedBox(height: Space.lg),
        if (r.amount != null) MoneyText(r.amount!, emphasis: MoneyEmphasis.hero),
        const SizedBox(height: Space.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
            child: Column(
              children: [
                row('Paid to', vendorName ?? (r.merchant.isNotEmpty ? r.merchant : '—')),
                if (r.date != null) row('Date', fmtDate(r.date!)),
                if (r.category != null) row('Category', r.category!),
                if (r.account != null) row('Paid from', r.account!),
                if (r.note.isNotEmpty) row('Note', r.note),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        if (r.billId != null)
          OutlinedButton.icon(
            onPressed: () => openBillDetail(context, r.billId!),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Open the bill'),
          )
        else
          Text('Recorded as money out. You\'ll find it in Accounting.',
              style: text.bodySmall, textAlign: TextAlign.center),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: _PhotoAndContent(receipt: r, content: content),
    );
  }
}

// --------------------------------------------------------------- layout

/// Wide: photo left (pinch to zoom), details right. Narrow: photo on top.
class _PhotoAndContent extends StatelessWidget {
  const _PhotoAndContent({required this.receipt, required this.content});

  final Receipt receipt;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final l = context.ledger;
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 840) {
        return Row(
          children: [
            Expanded(
              child: Container(
                color: l.subtleFill,
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Space.xl),
                      child: Image.memory(receipt.imageBytes, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ),
            VerticalDivider(width: 1, color: l.hairline),
            SizedBox(
              width: 420,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xxl),
                children: [content],
              ),
            ),
          ],
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xxl),
        children: [
          Center(child: ReceiptThumb(receipt.imageBytes, size: 220, zoomable: true)),
          const SizedBox(height: Space.xs),
          Center(
            child: Text('Tap the photo to zoom', style: Theme.of(context).textTheme.bodySmall),
          ),
          content,
        ],
      );
    });
  }
}
