import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/account/account_bloc.dart';
import '../../../components/account_dialog.dart';
import '../../../components/money_text.dart';
import '../../../config/layout.dart';
import '../../../models/account_model.dart';
import '../../../repository/setting_repository.dart';
import '../../../routes/routes.dart';
import '../../../theme/colors.dart';
import '../ledger_scope.dart';

/// The chart of accounts, one tab per account type, with today's balances.
class ChartOfAccountsPage extends StatelessWidget {
  const ChartOfAccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: AccountType.values.length,
      child: Builder(builder: (context) {
        return BlocListener<AccountBloc, AccountState>(
          listenWhen: (prev, next) => next.error != null && prev.error != next.error,
          listener: (context, state) => ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.error!))),
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Chart of accounts'),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final t in AccountType.values) Tab(text: t.plural)],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => showAccountDialog(context,
                  type: AccountType.values[DefaultTabController.of(context).index]),
              icon: const Icon(Icons.add),
              label: const Text('Add account'),
            ),
            body: TabBarView(
              children: [for (final t in AccountType.values) _AccountList(type: t)],
            ),
          ),
        );
      }),
    );
  }
}

class _AccountList extends StatefulWidget {
  const _AccountList({required this.type});

  final AccountType type;

  @override
  State<_AccountList> createState() => _AccountListState();
}

class _AccountListState extends State<_AccountList> {
  bool _showArchived = false;

  Future<void> _actions(Account a) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(a.display, style: Theme.of(ctx).textTheme.titleMedium),
              subtitle: Text(a.description.isEmpty ? a.type.label : a.description),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.list_alt_rounded),
              title: const Text('View transactions'),
              onTap: () => Navigator.pop(ctx, 'view'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            if (!a.isSystem)
              ListTile(
                leading: Icon(a.archived ? Icons.unarchive_outlined : Icons.archive_outlined),
                title: Text(a.archived ? 'Restore' : 'Archive'),
                subtitle: a.archived ? null : const Text('Hide it from pickers; history stays'),
                onTap: () => Navigator.pop(ctx, 'archive'),
              ),
            const SizedBox(height: Space.sm),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'view':
        await Navigator.pushNamed(context, PageRoutes.reportAccount,
            arguments: AccountReportArgs(a.id));
      case 'edit':
        await showAccountDialog(context, account: a);
      case 'archive':
        context.read<AccountBloc>().add(ArchiveAccount(a.id, archived: !a.archived));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AccountBloc>().state;
    final today = context.read<SettingRepository>().today;
    final ledger = watchLedger(context);
    final net = ledger.netByAccount(to: today);
    final l = context.ledger;
    final text = Theme.of(context).textTheme;
    final all = state.accounts.where((a) => a.type == widget.type).toList();
    final active = all.where((a) => !a.archived).toList();
    final archived = all.where((a) => a.archived).toList();

    Widget tile(Account a) {
      final n = net[a.id] ?? 0;
      final balance = a.type.debitNormal ? n : -n;
      return ListTile(
        onTap: () => _actions(a),
        leading: SizedBox(
          width: 48,
          child: Text(a.code, style: text.labelLarge?.copyWith(color: l.muted)),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: a.archived ? TextStyle(color: l.muted) : null),
            ),
            if (a.isMoney) ...[
              const SizedBox(width: Space.sm),
              Icon(Icons.account_balance_wallet_outlined, size: 16, color: l.muted),
            ],
            if (a.isSystem) ...[
              const SizedBox(width: Space.sm),
              Tooltip(
                message: 'The app posts to this account automatically',
                child: Icon(Icons.lock_outline, size: 14, color: l.muted),
              ),
            ],
          ],
        ),
        subtitle: a.description.isEmpty
            ? null
            : Text(a.description, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: MoneyText(balance),
      );
    }

    return LayoutBuilder(builder: (context, c) {
      final pad = sidePadding(c.maxWidth, maxWidth: 760, min: 0);
      return ListView(
        padding: EdgeInsets.fromLTRB(pad, Space.sm, pad, 96),
        children: [
          for (final a in active) tile(a),
          if (active.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Text('No ${widget.type.plural.toLowerCase()} accounts.',
                  style: text.bodyMedium?.copyWith(color: l.muted)),
            ),
          if (archived.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            TextButton(
              onPressed: () => setState(() => _showArchived = !_showArchived),
              child: Text(_showArchived
                  ? 'Hide archived'
                  : 'Show ${archived.length} archived'),
            ),
            if (_showArchived) for (final a in archived) tile(a),
          ],
        ],
      );
    });
  }
}
