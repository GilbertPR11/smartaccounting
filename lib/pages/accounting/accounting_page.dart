import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/account/account_bloc.dart';
import '../../bloc/journal/journal_bloc.dart';
import '../../bloc/transaction/transaction_bloc.dart';
import '../../components/centered_list_view.dart';
import '../../components/divided.dart';
import '../../components/initials_avatar.dart';
import '../../components/money_text.dart';
import '../../components/section_header.dart';
import '../../components/transaction_tile.dart';
import '../../models/account_model.dart';
import '../../repository/setting_repository.dart';
import '../../routes/routes.dart';
import '../../theme/colors.dart';
import '../../utils/reports.dart';
import '../home/app_shell.dart';
import 'accounting_flows.dart';
import 'ledger_scope.dart';

/// Accounting: profit at a glance, then the books themselves —
/// transactions, chart of accounts and reports.
class AccountingPage extends StatelessWidget {
  const AccountingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final today = context.read<SettingRepository>().today;
    final ledger = watchLedger(context);
    final accounts = context.watch<AccountBloc>().state;
    final txns = context.watch<TransactionBloc>().state.transactions;
    final journalCount = context.watch<JournalBloc>().state.journals.length;
    final l = context.ledger;
    final text = Theme.of(context).textTheme;

    final month = profitAndLoss(ledger, DateTime(today.year, today.month, 1), today);
    final year = profitAndLoss(ledger, DateTime(today.year, 1, 1), today);
    final uncategorized = txns.where((t) => t.allocations.any((a) {
          final acc = accounts.byName(a.$1);
          return acc == null ||
              acc.role == AccountRole.uncategorizedIncome ||
              acc.role == AccountRole.uncategorizedExpense;
        })).length;

    final unreconciled = txns.where((t) => !t.reconciled).length;

    void push(String route) => Navigator.pushNamed(context, route);

    Widget row(IconData icon, String title, String subtitle, VoidCallback onTap, {Widget? trailing}) =>
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

    Widget stat(String label, double value) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodySmall),
                const SizedBox(height: Space.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MoneyText(value,
                      color: value >= 0 ? l.moneyIn : l.moneyOut, emphasis: MoneyEmphasis.large),
                ),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(leading: AppShell.menuButton(context), title: const Text('Accounting')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'accounting-fab',
        onPressed: () => openTransactionForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Transaction'),
      ),
      body: CenteredListView(
        maxWidth: 820,
        bottom: 96,
        children: [
          Card(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  stat('Profit this month', month.netProfit),
                  VerticalDivider(width: 1, color: l.hairline),
                  stat('Profit this year', year.netProfit),
                ],
              ),
            ),
          ),
          if (uncategorized > 0) ...[
            const SizedBox(height: Space.md),
            Card(
              child: ListTile(
                leading: IconBadge(Icons.help_outline_rounded, color: l.warning),
                title: Text(uncategorized == 1
                    ? '1 transaction needs a category'
                    : '$uncategorized transactions need a category'),
                subtitle: const Text('Uncategorized money makes reports less useful'),
                trailing: Icon(Icons.chevron_right, color: l.muted),
                onTap: () => push(PageRoutes.transactions),
              ),
            ),
          ],
          const SectionHeader('Books'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: divided([
                row(Icons.swap_horiz_rounded, 'Transactions',
                    'Categorise, split and tag money in and out', () => push(PageRoutes.transactions),
                    trailing: Text('${txns.length + journalCount}', style: text.labelLarge)),
                row(Icons.fact_check_outlined, 'Reconciliation',
                    'Match your books to each bank statement',
                    () => push(PageRoutes.reconciliation),
                    trailing: unreconciled == 0
                        ? null
                        : Text('$unreconciled to tick', style: text.labelLarge)),
                row(Icons.download_rounded, 'Import bank statement',
                    'Paste a CSV export from online banking',
                    () => push(PageRoutes.importStatement)),
                row(Icons.account_tree_outlined, 'Chart of accounts',
                    'Assets, liabilities, equity, income and expenses',
                    () => push(PageRoutes.chartOfAccounts),
                    trailing: Text('${accounts.active.length}', style: text.labelLarge)),
                row(Icons.bar_chart_rounded, 'Reports',
                    'Profit & loss, balance sheet, SST and more', () => push(PageRoutes.reports)),
              ], l.hairline),
            ),
          ),
          if (txns.isNotEmpty) ...[
            SectionHeader(
              'Recent transactions',
              action: TextButton(
                onPressed: () => push(PageRoutes.transactions),
                child: const Text('See all'),
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: divided([
                  for (final t in txns.take(6))
                    TransactionTile(
                        transaction: t, onTap: () => openTransactionForm(context, transaction: t)),
                ], l.hairline),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
