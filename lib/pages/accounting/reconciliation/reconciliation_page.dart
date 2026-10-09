import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/account/account_bloc.dart';
import '../../../bloc/reconciliation/reconciliation_bloc.dart';
import '../../../bloc/transaction/transaction_bloc.dart';
import '../../../components/centered_list_view.dart';
import '../../../components/divided.dart';
import '../../../components/initials_avatar.dart';
import '../../../components/money_text.dart';
import '../../../components/section_header.dart';
import '../../../repository/setting_repository.dart';
import '../../../routes/routes.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import '../ledger_scope.dart';

/// Every bank and cash account: its balance in the books, when it was last
/// reconciled, and what's still to tick off. Plus the history, with undo.
class ReconciliationPage extends StatelessWidget {
  const ReconciliationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final today = context.read<SettingRepository>().today;
    final accounts = context.watch<AccountBloc>().state.money;
    final recs = context.watch<ReconciliationBloc>().state;
    final txns = context.watch<TransactionBloc>().state.transactions;
    final ledger = watchLedger(context);
    final l = context.ledger;
    final text = Theme.of(context).textTheme;

    return BlocListener<ReconciliationBloc, ReconciliationState>(
      listenWhen: (prev, next) => next.error != null && prev.error != next.error,
      listener: (context, state) =>
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!))),
      child: Scaffold(
        appBar: AppBar(title: const Text('Reconciliation')),
        body: CenteredListView(
          maxWidth: 760,
          children: [
            Text(
              'Once a month, match each account to its bank statement. It catches '
              'missing, duplicated and mistyped transactions.',
              style: text.bodyMedium?.copyWith(color: l.muted),
            ),
            const SectionHeader('Accounts'),
            for (final a in accounts) ...[
              Builder(builder: (context) {
                final last = recs.latestFor(a.name);
                final open = txns.where((t) => t.account == a.name && !t.reconciled).length;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            IconBadge(Icons.account_balance_wallet_outlined,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: Space.md),
                            Expanded(child: Text(a.name, style: text.titleMedium)),
                            MoneyText(ledger.balanceOf(a, to: today),
                                style: text.titleMedium),
                          ],
                        ),
                        const SizedBox(height: Space.sm),
                        Text(
                          last == null
                              ? 'Never reconciled'
                              : 'Reconciled to ${fmtDate(last.statementDate)} at ${money(last.endingBalance)}',
                          style: text.bodySmall,
                        ),
                        Text(
                          open == 0
                              ? 'Every transaction is reconciled'
                              : open == 1
                                  ? '1 transaction not reconciled yet'
                                  : '$open transactions not reconciled yet',
                          style: text.bodySmall?.copyWith(color: open == 0 ? l.moneyIn : l.warning),
                        ),
                        const SizedBox(height: Space.md),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.tonalIcon(
                            onPressed: () => Navigator.pushNamed(
                                context, PageRoutes.reconcileAccount,
                                arguments: a.name),
                            icon: const Icon(Icons.checklist_rounded, size: 18),
                            label: const Text('Reconcile'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: Space.sm),
            ],
            if (recs.reconciliations.isNotEmpty) ...[
              const SectionHeader('History'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: divided([
                    for (final r in recs.reconciliations)
                      ListTile(
                        leading: IconBadge(Icons.verified_outlined, color: l.moneyIn),
                        title: Text('${r.account} · ${fmtDate(r.statementDate)}'),
                        subtitle: Text(
                            '${r.transactionIds.length} transactions · done ${fmtDate(r.completedOn)}'),
                        trailing: recs.latestFor(r.account)?.id == r.id
                            ? TextButton(
                                onPressed: () => context
                                    .read<ReconciliationBloc>()
                                    .add(UndoReconciliation(r.id)),
                                child: const Text('Undo'),
                              )
                            : MoneyText(r.endingBalance),
                      ),
                  ], l.hairline),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
