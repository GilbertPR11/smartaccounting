import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/bill/bill_bloc.dart';
import '../../../bloc/receipt/receipt_bloc.dart';
import '../../../bloc/transaction/transaction_bloc.dart';
import '../../../bloc/vendor/vendor_bloc.dart';
import '../../../components/centered_list_view.dart';
import '../../../components/divided.dart';
import '../../../components/initials_avatar.dart';
import '../../../components/money_text.dart';
import '../../../components/receipt_thumb.dart';
import '../../../components/section_header.dart';
import '../../../components/status_chip.dart';
import '../../../components/transaction_tile.dart';
import '../../../config/constants.dart';
import '../../../models/bill_model.dart';
import '../../../models/invoice_model.dart';
import '../../../repository/setting_repository.dart';
import '../../../routes/routes.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';

class BillDetailPage extends StatefulWidget {
  const BillDetailPage({
    super.key,
    required this.billId,
    this.justCreated = false,
    this.embedded = false,
  });

  final String billId;
  final bool justCreated;

  /// True when shown as the right-hand pane of the bill list.
  final bool embedded;

  @override
  State<BillDetailPage> createState() => _BillDetailPageState();
}

class _BillDetailPageState extends State<BillDetailPage> {
  @override
  void initState() {
    super.initState();
    if (widget.justCreated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Bill saved')));
      });
    }
  }

  Future<void> _pay(Bill bill) async {
    final settings = context.read<SettingRepository>();
    final accounts = settings.accounts;
    final amount = TextEditingController(text: bill.balance.toStringAsFixed(2));
    var account = accounts.first;
    final key = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Pay bill'),
          content: SizedBox(
            width: 360,
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amount,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Amount', prefixText: '${Constants.currency} '),
                    validator: (v) {
                      final n = parseAmount(v ?? '');
                      if (n == null || n <= 0) return 'Enter the amount paid';
                      if (n > bill.balance + 0.004) return 'Only ${money(bill.balance)} is due';
                      return null;
                    },
                  ),
                  const SizedBox(height: Space.md),
                  DropdownButtonFormField<String>(
                    value: account,
                    decoration: const InputDecoration(labelText: 'Paid from'),
                    items: [
                      for (final a in accounts) DropdownMenuItem(value: a, child: Text(a)),
                    ],
                    onChanged: (v) => setLocal(() => account = v ?? account),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Record payment'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final paid = parseAmount(amount.text)!;
    context.read<BillBloc>().add(
        PayBill(billId: bill.id, amount: paid, date: settings.today, account: account));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Recorded payment of ${money(paid)}')));
  }

  @override
  Widget build(BuildContext context) {
    final today = context.read<SettingRepository>().today;
    final bill = context.watch<BillBloc>().state.byId(widget.billId);
    if (bill == null) {
      return const Scaffold(body: Center(child: Text('Bill not found')));
    }
    final vendor = context.watch<VendorBloc>().state.byId(bill.vendorId);
    final payments = context
        .watch<TransactionBloc>()
        .state
        .transactions
        .where((t) => t.billId == bill.id)
        .toList();
    final receipts =
        context.watch<ReceiptBloc>().state.receipts.where((r) => r.billId == bill.id).toList();
    final status = bill.statusOn(today);
    final l = context.ledger;
    final text = Theme.of(context).textTheme;
    final vendorName = vendor?.name ?? 'Unknown vendor';

    Widget fact(String label, String value, {Color? color}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.bodySmall),
              const SizedBox(height: 2),
              Text(value, style: text.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w500)),
            ],
          ),
        );

    return BlocListener<BillBloc, BillState>(
      listenWhen: (a, b) => b.error != null && a.error != b.error,
      listener: (context, s) =>
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.error!))),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.embedded,
          title: Text(bill.number.isEmpty ? 'Bill' : bill.number),
        ),
        bottomNavigationBar: bill.balance > 0.004
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.md),
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _pay(bill),
                          icon: const Icon(Icons.payments_outlined),
                          label: Text('Pay ${money(bill.balance)}'),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : null,
        body: CenteredListView(
          maxWidth: 720,
          children: [
            // Who and how much.
            Row(
              children: [
                InitialsAvatar(vendorName, size: 48),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vendorName, style: text.titleLarge),
                      const SizedBox(height: 2),
                      StatusChip(status),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xl),
            Text(bill.balance > 0.004 ? 'Left to pay' : 'Total paid', style: text.bodySmall),
            MoneyText(bill.balance > 0.004 ? bill.balance : bill.total,
                emphasis: MoneyEmphasis.hero),
            const SizedBox(height: Space.lg),
            Row(
              children: [
                fact('Bill date', fmtDate(bill.issueDate)),
                fact(
                  'Due',
                  bill.balance > 0.004 ? relativeDue(bill.dueDate, today) : fmtDate(bill.dueDate),
                  color: status == InvoiceStatus.overdue ? l.moneyOut : null,
                ),
                fact('Paid so far', money(bill.amountPaid)),
              ],
            ),

            const SectionHeader('What it\'s for'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Column(
                  children: [
                    for (final line in bill.lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(line.description, style: text.bodyLarge),
                                  Text(
                                    line.tax == null
                                        ? line.category
                                        : '${line.category}, ${line.tax!.label}',
                                    style: text.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            MoneyText(line.amount),
                          ],
                        ),
                      ),
                    Divider(color: l.hairline),
                    const SizedBox(height: Space.sm),
                    if (bill.taxTotal > 0) ...[
                      _TotalRow(label: 'Subtotal', amount: bill.subtotal),
                      _TotalRow(label: 'Tax', amount: bill.taxTotal),
                    ],
                    _TotalRow(label: 'Total', amount: bill.total, bold: true),
                  ],
                ),
              ),
            ),
            if (bill.notes.isNotEmpty) ...[
              const SectionHeader('Notes'),
              Text(bill.notes, style: text.bodyMedium),
            ],

            if (receipts.isNotEmpty) ...[
              const SectionHeader('Receipts'),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final r in receipts) ReceiptThumb(r.imageBytes, size: 88, zoomable: true),
                ],
              ),
            ],

            SectionHeader(payments.isEmpty ? 'Payments' : 'Payments (${payments.length})'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: payments.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(Space.lg),
                      child: Text('No payments yet. Payments you record appear here and in '
                          'Accounting.', style: text.bodyMedium?.copyWith(color: l.muted)),
                    )
                  : Column(
                      children: divided([
                        for (final t in payments) TransactionTile(transaction: t),
                      ], l.hairline),
                    ),
            ),
            if (vendor != null) ...[
              const SizedBox(height: Space.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, PageRoutes.bills,
                      arguments: BillListArgs(vendorId: vendor.id)),
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  label: Text('All bills from ${vendor.name}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.amount, this.bold = false});

  final String label;
  final double amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = bold ? text.titleSmall : text.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          MoneyText(amount, style: style?.copyWith(fontWeight: bold ? FontWeight.w700 : null)),
        ],
      ),
    );
  }
}
