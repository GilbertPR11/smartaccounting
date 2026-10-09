import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/bill_form/bill_form_bloc.dart';
import '../../../bloc/product/product_bloc.dart';
import '../../../bloc/receipt/receipt_bloc.dart';
import '../../../bloc/vendor/vendor_bloc.dart';
import '../../../components/centered_list_view.dart';
import '../../../components/divided.dart';
import '../../../components/initials_avatar.dart';
import '../../../components/money_text.dart';
import '../../../components/receipt_thumb.dart';
import '../../../components/section_header.dart';
import '../../../components/vendor_dialog.dart';
import '../../../config/constants.dart';
import '../../../models/bill_model.dart';
import '../../../models/product_model.dart';
import '../../../models/receipt_model.dart';
import '../../../repository/bill_repository.dart';
import '../../../repository/setting_repository.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import 'widgets/bill_line_editor.dart';

/// Enter a bill from a vendor. Pops with the created [Bill].
/// When [receiptId] is given, pre-fills from that receipt and attaches it.
class BillFormPage extends StatelessWidget {
  const BillFormPage({super.key, this.vendorId, this.receiptId, this.receipt});

  final String? vendorId;
  final String? receiptId;

  /// Latest edited copy of the receipt, if the caller has one.
  final Receipt? receipt;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => BillFormBloc(repository: ctx.read<BillRepository>()),
      child: _BillFormView(vendorId: vendorId, receiptId: receiptId, receipt: receipt),
    );
  }
}

class _BillFormView extends StatefulWidget {
  const _BillFormView({this.vendorId, this.receiptId, this.receipt});

  final String? vendorId;
  final String? receiptId;
  final Receipt? receipt;

  @override
  State<_BillFormView> createState() => _BillFormViewState();
}

class _BillFormViewState extends State<_BillFormView> {
  final _number = TextEditingController();
  final _notes = TextEditingController();
  String? _vendorId;
  late DateTime _issueDate;
  int _termsDays = 30;
  List<BillLine> _lines = [];
  Receipt? _receipt;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _issueDate = context.read<SettingRepository>().today;
    _vendorId = widget.vendorId;

    final r = widget.receipt ?? context.read<ReceiptBloc>().state.byId(widget.receiptId);
    if (r != null) {
      _receipt = r;
      _vendorId ??= r.vendorId;
      if (r.date != null) _issueDate = r.date!;
      if (r.amount != null && r.amount! > 0) {
        _lines = [
          BillLine(
            description: r.merchant.isNotEmpty ? r.merchant : (r.category ?? 'Expense'),
            category: r.category ?? _defaultCategory ?? 'Other',
            amount: r.amount!,
          ),
        ];
      }
      _notes.text = r.note;
    }
  }

  @override
  void dispose() {
    _number.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? get _defaultCategory =>
      context.read<VendorBloc>().state.byId(_vendorId)?.defaultCategory;

  DateTime get _dueDate => _issueDate.add(Duration(days: _termsDays));
  double get _subtotal => round2(_lines.fold<double>(0, (s, l) => s + l.amount));
  double get _tax => round2(_lines.fold<double>(0, (s, l) => s + l.taxAmount));
  double get _total => round2(_subtotal + _tax);

  Future<void> _pickVendor() async {
    final vendors = context.read<VendorBloc>().state.vendors;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, controller) => ListView(
          controller: controller,
          children: [
            ListTile(
              leading: const Icon(Icons.add_business_outlined),
              title: const Text('New vendor'),
              onTap: () => Navigator.pop(ctx, '__new__'),
            ),
            const Divider(height: 1),
            for (final v in vendors)
              ListTile(
                leading: InitialsAvatar(v.name),
                title: Text(v.name),
                subtitle: v.defaultCategory == null ? null : Text(v.defaultCategory!),
                trailing: v.id == _vendorId ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(ctx, v.id),
              ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    final id = result == '__new__' ? (await showAddVendorDialog(context))?.id : result;
    if (id == null || !mounted) return;
    setState(() {
      _vendorId = id;
      // Lines entered before choosing the vendor pick up its usual category
      // only if they were on the generic fallback.
      final cat = context.read<VendorBloc>().state.byId(id)?.defaultCategory;
      if (cat != null) {
        _lines = [
          for (final l in _lines)
            l.category == 'Other'
                ? BillLine(description: l.description, category: cat, amount: l.amount, tax: l.tax)
                : l,
        ];
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _issueDate = dateOnly(picked));
  }

  /// For a new line, offers saved "products you buy" first (they pre-fill
  /// description, cost, tax and category).
  /// Returns (cancelled, draft): draft is null for a custom line.
  Future<(bool, BillLine?)> _draftFromProduct() async {
    final products = context.read<ProductBloc>().state.bought;
    if (products.isEmpty) return (false, null);
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Custom line'),
              onTap: () => Navigator.pop(ctx, 'custom'),
            ),
            const Divider(height: 1),
            for (final p in products)
              ListTile(
                title: Text(p.name),
                subtitle: Text(p.expenseCategory ?? ''),
                trailing: MoneyText(p.purchasePrice ?? 0),
                onTap: () => Navigator.pop(ctx, p),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return (true, null);
    if (choice is! Product) return (false, null);
    return (
      false,
      BillLine(
        description: choice.name,
        category: choice.expenseCategory ?? _defaultCategory ?? 'Other',
        amount: choice.purchasePrice ?? 0,
        tax: choice.tax,
      ),
    );
  }

  Future<void> _editLine([int? index]) async {
    BillLine? draft;
    if (index == null) {
      final (cancelled, picked) = await _draftFromProduct();
      if (cancelled || !mounted) return;
      draft = picked;
    }
    final line = await showBillLineEditor(
      context,
      line: index == null ? draft : _lines[index],
      defaultCategory: _defaultCategory,
      isNew: index == null,
    );
    if (line == null) return;
    setState(() {
      _lines = [..._lines];
      if (index == null) {
        _lines.add(line);
      } else {
        _lines[index] = line;
      }
    });
  }

  void _save() {
    setState(() => _showErrors = true);
    if (_vendorId == null || _lines.isEmpty) return;
    context.read<BillFormBloc>().add(SubmitBill(
          vendorId: _vendorId!,
          number: _number.text,
          issueDate: _issueDate,
          dueDate: _dueDate,
          lines: _lines,
          notes: _notes.text,
          receiptId: _receipt?.id,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final vendor = context.watch<VendorBloc>().state.byId(_vendorId);
    final submitting =
        context.watch<BillFormBloc>().state.status == BillFormStatus.submitting;
    final l = context.ledger;
    final text = Theme.of(context).textTheme;

    return BlocListener<BillFormBloc, BillFormState>(
      listener: (context, s) {
        if (s.status == BillFormStatus.success) {
          Navigator.pop(context, s.created);
        } else if (s.status == BillFormStatus.failure) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(s.error ?? 'Could not save the bill.')));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_receipt == null ? 'New bill' : 'Bill from receipt')),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total', style: text.bodySmall),
                      MoneyText(_total, emphasis: MoneyEmphasis.large),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: submitting ? null : _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save bill'),
                ),
              ],
            ),
          ),
        ),
        body: CenteredListView(
          maxWidth: 720,
          children: [
            if (_receipt != null)
              Card(
                child: ListTile(
                  leading: ReceiptThumb(_receipt!.imageBytes, zoomable: true),
                  title: const Text('This receipt will be attached'),
                  subtitle: const Text('Tap the photo to check the details'),
                ),
              ),

            const SectionHeader('Vendor'),
            Card(
              shape: _showErrors && vendor == null
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.container),
                      side: BorderSide(color: l.moneyOut))
                  : null,
              child: ListTile(
                leading: vendor == null
                    ? const IconBadge(Icons.storefront_outlined)
                    : InitialsAvatar(vendor.name),
                title: Text(vendor?.name ?? 'Choose a vendor'),
                subtitle: _showErrors && vendor == null
                    ? Text('Choose who the bill is from', style: TextStyle(color: l.moneyOut))
                    : (vendor?.defaultCategory == null ? null : Text(vendor!.defaultCategory!)),
                trailing: const Icon(Icons.expand_more_rounded),
                onTap: _pickVendor,
              ),
            ),

            const SectionHeader('Details'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _number,
                      decoration: const InputDecoration(
                        labelText: 'Vendor\'s bill number (optional)',
                        helperText: 'As printed on their bill, so you can match it later',
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(Radii.control),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Bill date',
                                suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                              ),
                              child: Text(fmtDate(_issueDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Due'),
                            child: Text(fmtDate(_dueDate)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.md),
                    Text('Pay within', style: text.bodySmall),
                    const SizedBox(height: Space.xs),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.xs,
                      children: [
                        for (final e in Constants.billTerms.entries)
                          ChoiceChip(
                            label: Text(e.value),
                            selected: _termsDays == e.key,
                            onSelected: (_) => setState(() => _termsDays = e.key),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SectionHeader(
              'Lines',
              action: TextButton.icon(
                onPressed: () => _editLine(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add line'),
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              shape: _showErrors && _lines.isEmpty
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.container),
                      side: BorderSide(color: l.moneyOut))
                  : null,
              child: _lines.isEmpty
                  ? ListTile(
                      leading: const IconBadge(Icons.add_rounded),
                      title: const Text('Add what the bill is for'),
                      subtitle: _showErrors
                          ? Text('A bill needs at least one line',
                              style: TextStyle(color: l.moneyOut))
                          : const Text('For example "Office rent – November"'),
                      onTap: () => _editLine(),
                    )
                  : Column(
                      children: divided([
                        for (var i = 0; i < _lines.length; i++)
                          ListTile(
                            title: Text(_lines[i].description),
                            subtitle: Text(_lines[i].tax == null
                                ? _lines[i].category
                                : '${_lines[i].category}, ${_lines[i].tax!.label}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                MoneyText(_lines[i].amount),
                                IconButton(
                                  tooltip: 'Remove line',
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () => setState(
                                      () => _lines = [..._lines]..removeAt(i)),
                                ),
                              ],
                            ),
                            onTap: () => _editLine(i),
                          ),
                      ], l.hairline, indent: Space.lg),
                    ),
            ),
            if (_tax > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, 0),
                child: Row(
                  children: [
                    Expanded(child: Text('Includes tax', style: text.bodySmall)),
                    MoneyText(_tax, style: text.bodySmall),
                  ],
                ),
              ),

            const SectionHeader('Notes'),
            TextField(
              controller: _notes,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(hintText: 'Anything to remember about this bill'),
            ),
          ],
        ),
      ),
    );
  }
}
