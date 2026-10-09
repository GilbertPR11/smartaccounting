import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/customer/customer_bloc.dart';
import '../../../bloc/invoice/invoice_bloc.dart';
import '../../../bloc/recurring/recurring_bloc.dart';
import '../../../components/centered_list_view.dart';
import '../../../components/divided.dart';
import '../../../components/initials_avatar.dart';
import '../../../components/invoice_tile.dart';
import '../../../components/money_text.dart';
import '../../../components/section_header.dart';
import '../../../components/status_chip.dart';
import '../../../models/recurring_invoice_model.dart';
import '../../../repository/setting_repository.dart';
import '../../../routes/routes.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import '../invoice/new_invoice_flow.dart';
import 'recurring_flows.dart';

enum _Action { edit, pause, resume, delete }

/// One schedule: its rhythm, the next dates, what it bills, and every
/// invoice it has issued.
class RecurringDetailPage extends StatefulWidget {
  const RecurringDetailPage({super.key, required this.scheduleId, this.justSaved = false});

  final String scheduleId;
  final bool justSaved;

  @override
  State<RecurringDetailPage> createState() => _RecurringDetailPageState();
}

class _RecurringDetailPageState extends State<RecurringDetailPage> {
  @override
  void initState() {
    super.initState();
    if (widget.justSaved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final r = context.read<RecurringBloc>().state.byId(widget.scheduleId);
        final issued = r?.issuedCount ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(issued == 0
              ? 'Schedule saved'
              : 'Schedule saved. $issued ${issued == 1 ? 'invoice' : 'invoices'} issued so far.'),
        ));
      });
    }
  }

  Future<void> _onAction(_Action action, RecurringInvoice r) async {
    final bloc = context.read<RecurringBloc>();
    switch (action) {
      case _Action.edit:
        await openRecurringForm(context, schedule: r);
      case _Action.pause:
        bloc.add(PauseRecurring(r.id, paused: true));
      case _Action.resume:
        final today = context.read<SettingRepository>().today;
        final skipping = r.nextDate != null && r.nextDate!.isBefore(today);
        if (skipping) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Resume schedule?'),
              content: const Text(
                  'Dates that passed while it was paused are skipped. '
                  'No invoices are back-dated.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true), child: const Text('Resume')),
              ],
            ),
          );
          if (ok != true) return;
        }
        bloc.add(PauseRecurring(r.id, paused: false));
      case _Action.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete this schedule?'),
            content: const Text(
                'No more invoices will be issued. Invoices it already issued are kept.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        bloc.add(DeleteRecurring(r.id));
        Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = context.read<SettingRepository>().today;
    final r = context.watch<RecurringBloc>().state.byId(widget.scheduleId);
    if (r == null) {
      return const Scaffold(body: Center(child: Text('Schedule not found')));
    }
    final customer = context.watch<CustomerBloc>().state.byId(r.customerId);
    final issued = context
        .watch<InvoiceBloc>()
        .state
        .invoices
        .where((i) => i.recurringId == r.id)
        .toList(); // newest first
    final l = context.ledger;
    final text = Theme.of(context).textTheme;
    final status = r.status;
    final next = r.nextDate;

    // The next few dates (stops at the end of the schedule).
    final upcoming = <DateTime>[];
    for (var n = r.issuedCount; upcoming.length < 3; n++) {
      if (r.copyWith(issuedCount: n).isFinished) break;
      upcoming.add(r.occurrence(n));
    }

    Widget fact(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 120, child: Text(label, style: text.bodySmall)),
              Expanded(child: Text(value, style: text.bodyMedium)),
            ],
          ),
        );

    return BlocListener<RecurringBloc, RecurringState>(
      listenWhen: (prev, next) => next.error != null && prev.error != next.error,
      listener: (context, state) =>
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!))),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recurring invoice'),
          actions: [
            PopupMenuButton<_Action>(
              tooltip: 'More',
              onSelected: (a) => _onAction(a, r),
              itemBuilder: (_) => [
                if (status != RecurringStatus.ended)
                  const PopupMenuItem(value: _Action.edit, child: Text('Edit')),
                if (status == RecurringStatus.active)
                  const PopupMenuItem(value: _Action.pause, child: Text('Pause')),
                if (status == RecurringStatus.paused)
                  const PopupMenuItem(value: _Action.resume, child: Text('Resume')),
                const PopupMenuItem(value: _Action.delete, child: Text('Delete')),
              ],
            ),
          ],
        ),
        body: CenteredListView(
          maxWidth: 760,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        InitialsAvatar(customer?.name ?? '?'),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Text(customer?.name ?? 'Unknown customer',
                              style: text.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        StatusChip.recurring(status),
                      ],
                    ),
                    const SizedBox(height: Space.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MoneyText(r.total, emphasis: MoneyEmphasis.large),
                        Flexible(
                          child: Text(' ${r.frequency.every}',
                              style: text.bodyMedium?.copyWith(color: l.muted)),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.md),
                    fact('Schedule', r.rhythm),
                    fact('First invoice', fmtDate(r.startDate)),
                    fact(
                      'Next invoice',
                      switch (status) {
                        RecurringStatus.ended => 'None, the schedule has ended',
                        RecurringStatus.paused => 'Paused',
                        RecurringStatus.active => next == null
                            ? '—'
                            : '${fmtDate(next)} (${relativeDay(next, today)})',
                      },
                    ),
                    fact('Payment terms',
                        r.termsDays == 0 ? 'Due on receipt' : 'Due ${r.termsDays} days after issue'),
                    fact('Issued so far', '${r.issuedCount}'),
                    if (status != RecurringStatus.ended) ...[
                      const SizedBox(height: Space.md),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: status == RecurringStatus.paused
                            ? FilledButton.tonalIcon(
                                onPressed: () => _onAction(_Action.resume, r),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Resume'),
                              )
                            : OutlinedButton.icon(
                                onPressed: () => _onAction(_Action.pause, r),
                                icon: const Icon(Icons.pause_rounded),
                                label: const Text('Pause'),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (upcoming.isNotEmpty && status == RecurringStatus.active) ...[
              const SectionHeader('Coming up'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: divided([
                    for (final d in upcoming)
                      ListTile(
                        leading: IconBadge(Icons.event_outlined,
                            color: Theme.of(context).colorScheme.primary),
                        title: Text(fmtDate(d)),
                        subtitle: Text(
                            'Due ${fmtDate(d.add(Duration(days: r.termsDays)))}'),
                        trailing: MoneyText(r.total),
                      ),
                  ], l.hairline),
                ),
              ),
            ],
            const SectionHeader('Items on each invoice'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: divided([
                  for (final line in r.lines)
                    ListTile(
                      title: Text(line.description),
                      subtitle: Text(line.tax == null
                          ? '${fmtQty(line.quantity)} × ${money(line.unitPrice)}'
                          : '${fmtQty(line.quantity)} × ${money(line.unitPrice)}, ${line.tax!.label}'),
                      trailing: MoneyText(line.total),
                    ),
                ], l.hairline),
              ),
            ),
            SectionHeader(
              'Invoices issued',
              action: TextButton(
                onPressed: () => Navigator.pushNamed(context, PageRoutes.invoices),
                child: const Text('All invoices'),
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: issued.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(Space.xl),
                      child: Text(
                        next == null
                            ? 'This schedule never issued an invoice.'
                            : 'The first invoice will be issued on ${fmtDate(next)}.',
                        style: text.bodyMedium?.copyWith(color: l.muted),
                      ),
                    )
                  : Column(
                      children: divided([
                        for (final inv in issued)
                          InvoiceTile(
                              invoice: inv, onTap: () => openInvoiceDetail(context, inv.id)),
                      ], l.hairline),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
