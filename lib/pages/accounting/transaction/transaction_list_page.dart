import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/account/account_bloc.dart';
import '../../../bloc/journal/journal_bloc.dart';
import '../../../bloc/transaction/transaction_bloc.dart';
import '../../../components/centered_list_view.dart';
import '../../../components/divided.dart';
import '../../../components/empty_state.dart';
import '../../../components/initials_avatar.dart';
import '../../../components/money_text.dart';
import '../../../components/search_field.dart';
import '../../../components/transaction_tile.dart';
import '../../../models/account_model.dart';
import '../../../models/journal_model.dart';
import '../../../models/transaction_model.dart';
import '../../../routes/routes.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import '../accounting_flows.dart';

enum _View { bank, journals }

/// Every bank and cash transaction (filterable), plus manual journal entries.
/// Tap one to categorise, split, tag or edit it.
class TransactionListPage extends StatefulWidget {
  const TransactionListPage({super.key});

  @override
  State<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends State<TransactionListPage> {
  _View _view = _View.bank;
  TransactionType? _type; // null = all
  String? _account; // null = all
  String? _tagId; // null = all
  bool _uncategorizedOnly = false;
  String _query = '';

  Future<void> _add() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.south_west_rounded),
              title: const Text('Money in'),
              subtitle: const Text('Income, a loan received, owner money…'),
              onTap: () => Navigator.pop(ctx, 'in'),
            ),
            ListTile(
              leading: const Icon(Icons.north_east_rounded),
              title: const Text('Money out'),
              subtitle: const Text('An expense, a purchase, owner drawings…'),
              onTap: () => Navigator.pop(ctx, 'out'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_vert_rounded),
              title: const Text('Journal entry'),
              subtitle: const Text('An adjustment with no money moving'),
              onTap: () => Navigator.pop(ctx, 'journal'),
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Import bank statement'),
              subtitle: const Text('Paste a CSV export'),
              onTap: () => Navigator.pop(ctx, 'import'),
            ),
            const SizedBox(height: Space.sm),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'in':
        await openTransactionForm(context, type: TransactionType.income);
      case 'out':
        await openTransactionForm(context, type: TransactionType.expense);
      case 'journal':
        await openJournalForm(context);
      case 'import':
        await Navigator.pushNamed(context, PageRoutes.importStatement);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txnState = context.watch<TransactionBloc>().state;
    final accounts = context.watch<AccountBloc>().state;
    final journals = context.watch<JournalBloc>().state.journals;
    final l = context.ledger;
    final q = _query.trim().toLowerCase();

    // Uncategorised = no category, or one that isn't in the chart, or the
    // "Uncategorized …" accounts.
    bool isUncategorized(BankTransaction t) => t.allocations.any((a) {
          final acc = accounts.byName(a.$1);
          return acc == null ||
              acc.role == AccountRole.uncategorizedIncome ||
              acc.role == AccountRole.uncategorizedExpense;
        });

    final txns = txnState.transactions.where((t) {
      if (_type != null && t.type != _type) return false;
      if (_account != null && t.account != _account) return false;
      if (_tagId != null && !t.tagIds.contains(_tagId)) return false;
      if (_uncategorizedOnly && !isUncategorized(t)) return false;
      if (q.isEmpty) return true;
      return t.description.toLowerCase().contains(q) ||
          t.categoryLabel.toLowerCase().contains(q) ||
          t.amount.toStringAsFixed(2).contains(q);
    }).toList();
    final uncategorizedCount = txnState.transactions.where(isUncategorized).length;

    final groups = <DateTime, List<BankTransaction>>{};
    for (final t in txns) {
      groups.putIfAbsent(DateTime(t.date.year, t.date.month), () => []).add(t);
    }

    final filters = <Widget>[
      SearchField(hint: 'Search description, category or amount', onChanged: (v) => setState(() => _query = v)),
      const SizedBox(height: Space.sm),
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            // Menu values can't be null (null means "dismissed"), so '' = all.
            _MenuChip(
              label: switch (_type) {
                null => 'In & out',
                TransactionType.income => 'Money in',
                TransactionType.expense => 'Money out',
              },
              active: _type != null,
              options: const {'': 'In & out', 'in': 'Money in', 'out': 'Money out'},
              onSelected: (v) => setState(() => _type = switch (v) {
                    'in' => TransactionType.income,
                    'out' => TransactionType.expense,
                    _ => null,
                  }),
            ),
            const SizedBox(width: Space.sm),
            _MenuChip(
              label: _account ?? 'All accounts',
              active: _account != null,
              options: {'': 'All accounts', for (final a in accounts.money) a.name: a.name},
              onSelected: (v) => setState(() => _account = v.isEmpty ? null : v),
            ),
            if (txnState.tags.isNotEmpty) ...[
              const SizedBox(width: Space.sm),
              _MenuChip(
                label: txnState.tagById(_tagId ?? '')?.name ?? 'All tags',
                active: _tagId != null,
                options: {'': 'All tags', for (final t in txnState.tags) t.id: t.name},
                onSelected: (v) => setState(() => _tagId = v.isEmpty ? null : v),
              ),
            ],
            const SizedBox(width: Space.sm),
            FilterChip(
              label: Text('Uncategorized ($uncategorizedCount)'),
              selected: _uncategorizedOnly,
              onSelected: (v) => setState(() => _uncategorizedOnly = v),
            ),
          ],
        ),
      ),
    ];

    final bankView = <Widget>[
      ...filters,
      if (groups.isEmpty)
        const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No transactions',
          message: 'Nothing matches these filters.',
          compact: true,
        ),
      for (final entry in groups.entries) ...[
        _MonthHeader(month: entry.key, txns: entry.value),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: divided([
              for (final t in entry.value)
                TransactionTile(
                  transaction: t,
                  onTap: () => openTransactionForm(context, transaction: t),
                ),
            ], l.hairline),
          ),
        ),
      ],
    ];

    final journalView = <Widget>[
      if (journals.isEmpty)
        EmptyState(
          icon: Icons.swap_vert_rounded,
          title: 'No journal entries',
          message: 'Use one for adjustments where no money moves, like depreciation '
              'or an expense the owner paid personally.',
          actionLabel: 'Add journal entry',
          onAction: () => openJournalForm(context),
        )
      else
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: divided([
              for (final j in journals) _JournalTile(entry: j, accounts: accounts),
            ], l.hairline),
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: CenteredListView(
        maxWidth: 820,
        bottom: 96,
        children: [
          SegmentedButton<_View>(
            showSelectedIcon: false,
            segments: [
              const ButtonSegment(value: _View.bank, label: Text('Bank & cash')),
              ButtonSegment(value: _View.journals, label: Text('Journal entries (${journals.length})')),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
          const SizedBox(height: Space.md),
          ...(_view == _View.bank ? bankView : journalView),
        ],
      ),
    );
  }
}

/// A chip that opens a menu of options.
class _MenuChip extends StatelessWidget {
  const _MenuChip({
    required this.label,
    required this.active,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final bool active;
  final Map<String, String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: label,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final e in options.entries)
          PopupMenuItem<String>(value: e.key, child: Text(e.value)),
      ],
      child: Chip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(label), const SizedBox(width: 2), const Icon(Icons.expand_more, size: 18)],
        ),
        backgroundColor: active ? Theme.of(context).colorScheme.secondaryContainer : null,
      ),
    );
  }
}

class _JournalTile extends StatelessWidget {
  const _JournalTile({required this.entry, required this.accounts});

  final JournalEntry entry;
  final AccountState accounts;

  @override
  Widget build(BuildContext context) {
    final debits = entry.lines.where((l) => l.debit > 0).map((l) => accounts.byId(l.accountId)?.name ?? '?');
    final credits = entry.lines.where((l) => l.credit > 0).map((l) => accounts.byId(l.accountId)?.name ?? '?');
    return ListTile(
      onTap: () => openJournalForm(context, entry: entry),
      leading: const IconBadge(Icons.swap_vert_rounded),
      title: Text(entry.description, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${fmtDateShort(entry.date)}   ${debits.join(', ')} ← ${credits.join(', ')}',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: MoneyText(entry.totalDebit),
    );
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
