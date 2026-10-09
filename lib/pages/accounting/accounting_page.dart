import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/transaction/transaction_bloc.dart';
import '../../components/centered_list_view.dart';
import '../../components/coming_soon.dart';
import '../../components/divided.dart';
import '../../components/empty_state.dart';
import '../../components/money_text.dart';
import '../../components/section_header.dart';
import '../../components/transaction_tile.dart';
import '../../models/transaction_model.dart';
import '../../theme/colors.dart';
import '../../utils/format.dart';
import '../../routes/routes.dart';
import '../purchases/purchase_flows.dart';
import '../sales/invoice/new_invoice_flow.dart';

/// Accounting: every transaction, grouped by month with that month's totals.
/// Chart of accounts and reports are planned.
class AccountingPage extends StatefulWidget {
  const AccountingPage({super.key});

  @override
  State<AccountingPage> createState() => _AccountingPageState();
}

class _AccountingPageState extends State<AccountingPage> {
  TransactionType? _type; // null = all

  @override
  Widget build(BuildContext context) {
    final l = context.ledger;
    final all = context.watch<TransactionBloc>().state.transactions; // newest first
    final txns = all.where((t) => _type == null || t.type == _type).toList();

    // Group by month (list is already newest first).
    final groups = <DateTime, List<BankTransaction>>{};
    for (final t in txns) {
      groups.putIfAbsent(DateTime(t.date.year, t.date.month), () => []).add(t);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Accounting')),
      body: CenteredListView(
        maxWidth: 820,
        children: [
          SegmentedButton<TransactionType?>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: null, label: Text('All')),
              ButtonSegment(value: TransactionType.income, label: Text('Money in')),
              ButtonSegment(value: TransactionType.expense, label: Text('Money out')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          if (groups.isEmpty)
            const EmptyState(
              icon: Icons.account_balance_outlined,
              title: 'No transactions',
              message: 'Bank and cash movements will appear here.',
              compact: true,
            ),
          for (final entry in groups.entries) ...[
            _MonthHeader(month: entry.key, txns: entry.value),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: divided([
                  for (final t in entry.value)
                    TransactionTile(transaction: t, onTap: () => _onTap(context, t)),
                ], l.hairline),
              ),
            ),
          ],
          const SectionHeader('Coming later'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: divided(const [
                ComingSoon(
                    icon: Icons.account_tree_outlined,
                    title: 'Chart of accounts',
                    subtitle: 'Assets, liabilities, income and expenses'),
                ComingSoon(
                    icon: Icons.bar_chart_rounded,
                    title: 'Reports',
                    subtitle: 'Profit and loss, balance sheet, SST summary'),
              ], l.hairline),
            ),
          ),
        ],
      ),
    );
  }

  void _onTap(BuildContext context, BankTransaction t) {
    final invoiceId = t.invoiceId;
    final billId = t.billId;
    final receiptId = t.receiptId;
    if (invoiceId != null) {
      openInvoiceDetail(context, invoiceId);
    } else if (billId != null) {
      openBillDetail(context, billId);
    } else if (receiptId != null) {
      Navigator.pushNamed(context, PageRoutes.receipt, arguments: receiptId);
    } else if (t.isInvoiceable) {
      openInvoiceForm(context, source: t);
    }
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month, required this.txns});

  final DateTime month;
  final List<BankTransaction> txns;

  @override
  Widget build(BuildContext context) {
    final l = context.ledger;
    final text = Theme.of(context).textTheme;
    final moneyIn = txns.where((t) => t.isIncome).fold<double>(0, (s, t) => s + t.amount);
    final moneyOut = txns.where((t) => !t.isIncome).fold<double>(0, (s, t) => s + t.amount);
    final small = text.bodySmall?.copyWith(fontWeight: FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, Space.xl, 2, Space.sm),
      child: Row(
        children: [
          Expanded(child: Text(fmtMonthYear(month), style: text.titleMedium)),
          if (moneyIn > 0) MoneyText(moneyIn, showSign: true, color: l.moneyIn, style: small),
          if (moneyIn > 0 && moneyOut > 0) const SizedBox(width: Space.md),
          if (moneyOut > 0) MoneyText(-moneyOut, style: small?.copyWith(color: l.muted)),
        ],
      ),
    );
  }
}
