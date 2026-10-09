import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/bill/bill_bloc.dart';
import '../../bloc/receipt/receipt_bloc.dart';
import '../../bloc/transaction/transaction_bloc.dart';
import '../../bloc/vendor/vendor_bloc.dart';
import '../../components/bill_tile.dart';
import '../../components/centered_list_view.dart';
import '../../components/divided.dart';
import '../../components/initials_avatar.dart';
import '../../components/money_text.dart';
import '../../components/receipt_thumb.dart';
import '../../components/section_header.dart';
import '../../components/transaction_tile.dart';
import '../../repository/setting_repository.dart';
import '../../routes/routes.dart';
import '../../theme/colors.dart';
import '../../utils/ledger_summary.dart';
import 'purchase_flows.dart';

/// Purchases: what you owe, what you've spent, and the receipts to file.
class PurchasesPage extends StatelessWidget {
  const PurchasesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final today = context.read<SettingRepository>().today;
    final l = context.ledger;
    final text = Theme.of(context).textTheme;
    final bills = context.watch<BillBloc>().state.bills;
    final receipts = context.watch<ReceiptBloc>().state;
    final vendorCount = context.watch<VendorBloc>().state.vendors.length;
    final expenses =
        context.watch<TransactionBloc>().state.transactions.where((t) => !t.isIncome).toList();

    final owed = LedgerSummary.payable(bills);
    final dueSoon = LedgerSummary.billsDueSoon(bills, today);
    final toReview = receipts.toReview;

    final monthStart = DateTime(today.year, today.month, 1);
    final thisMonth = expenses
        .where((t) => !t.date.isBefore(monthStart))
        .fold<double>(0, (s, t) => s + t.amount);

    // Spending by category this month, biggest first.
    final byCategory = <String, double>{};
    for (final t in expenses.where((t) => !t.date.isBefore(monthStart))) {
      byCategory.update(t.category, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    final categories = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    Widget navRow(IconData icon, String title, String subtitle, VoidCallback onTap,
            {Widget? trailing}) =>
        ListTile(
          leading: IconBadge(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null) ...[trailing, const SizedBox(width: Space.sm)],
              Icon(Icons.chevron_right, color: l.muted),
            ],
          ),
          onTap: onTap,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Purchases')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddPurchaseSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: CenteredListView(
        maxWidth: 820,
        bottom: 96,
        children: [
          // Summary.
          Card(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Stat(
                      label: 'You owe vendors',
                      value: owed,
                      color: dueSoon.any((b) => b.dueDate.isBefore(today)) ? l.moneyOut : null,
                    ),
                  ),
                  VerticalDivider(width: 1, color: l.hairline),
                  Expanded(child: _Stat(label: 'Spent this month', value: thisMonth)),
                ],
              ),
            ),
          ),

          // What to do next.
          if (dueSoon.isNotEmpty || toReview.isNotEmpty) ...[
            const SectionHeader('To do'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: divided([
                  for (final b in dueSoon.take(4))
                    BillTile(bill: b, onTap: () => openBillDetail(context, b.id)),
                  if (toReview.isNotEmpty)
                    ListTile(
                      leading: ReceiptThumb(toReview.first.imageBytes),
                      title: Text(toReview.length == 1
                          ? '1 receipt to review'
                          : '${toReview.length} receipts to review'),
                      subtitle: const Text('Add the amount and category to record them'),
                      trailing: Icon(Icons.chevron_right, color: l.muted),
                      onTap: () => toReview.length == 1
                          ? Navigator.pushNamed(context, PageRoutes.receipt,
                              arguments: toReview.first.id)
                          : Navigator.pushNamed(context, PageRoutes.receipts),
                    ),
                ], l.hairline),
              ),
            ),
          ],

          const SectionHeader('Manage'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: divided([
                navRow(
                  Icons.description_outlined,
                  'Bills',
                  'What you owe and when it\'s due',
                  () => Navigator.pushNamed(context, PageRoutes.bills),
                  trailing: Text(
                    '${bills.where((b) => b.balance > 0.004).length} to pay',
                    style: text.labelLarge,
                  ),
                ),
                navRow(
                  Icons.document_scanner_outlined,
                  'Receipts',
                  'Photos of things you\'ve paid for',
                  () => Navigator.pushNamed(context, PageRoutes.receipts),
                  trailing: toReview.isEmpty ? null : Badge(label: Text('${toReview.length}')),
                ),
                navRow(
                  Icons.storefront_outlined,
                  'Vendors',
                  'Who you buy from',
                  () => Navigator.pushNamed(context, PageRoutes.vendors),
                  trailing: Text('$vendorCount', style: text.labelLarge),
                ),
              ], l.hairline),
            ),
          ),

          if (categories.isNotEmpty) ...[
            const SectionHeader('Where it went this month'),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.xs),
                child: Column(
                  children: [
                    for (final c in categories)
                      _CategoryBar(
                        label: c.key,
                        amount: c.value,
                        share: thisMonth == 0 ? 0 : c.value / thisMonth,
                      ),
                  ],
                ),
              ),
            ),
          ],

          if (expenses.isNotEmpty) ...[
            const SectionHeader('Recent money out'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: divided([
                  for (final t in expenses.take(6))
                    TransactionTile(
                      transaction: t,
                      onTap: t.billId == null ? null : () => openBillDetail(context, t.billId!),
                    ),
                ], l.hairline),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: Space.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyText(value, color: color, emphasis: MoneyEmphasis.large),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.label, required this.amount, required this.share});

  final String label;
  final double amount;
  final double share;

  @override
  Widget build(BuildContext context) {
    final l = context.ledger;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: text.bodyMedium)),
              MoneyText(amount, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: share.clamp(0, 1),
              minHeight: 6,
              backgroundColor: l.subtleFill,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
