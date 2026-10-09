import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/recurring/recurring_bloc.dart';
import '../../../components/centered_list_view.dart';
import '../../../components/divided.dart';
import '../../../components/empty_state.dart';
import '../../../components/money_text.dart';
import '../../../components/recurring_tile.dart';
import '../../../components/section_header.dart';
import '../../../models/recurring_invoice_model.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import 'recurring_flows.dart';

/// Recurring invoices, grouped Active / Paused / Ended, with what they bring
/// in per month on top.
class RecurringListPage extends StatelessWidget {
  const RecurringListPage({super.key});

  /// What a schedule bills in an average month.
  static double monthlyValue(RecurringInvoice r) => round2(switch (r.frequency) {
        RecurFrequency.weekly => r.total * 52 / 12,
        RecurFrequency.monthly => r.total,
        RecurFrequency.quarterly => r.total / 3,
        RecurFrequency.yearly => r.total / 12,
      });

  @override
  Widget build(BuildContext context) {
    final all = context.watch<RecurringBloc>().state.schedules;
    final l = context.ledger;
    final text = Theme.of(context).textTheme;

    List<RecurringInvoice> withStatus(RecurringStatus s) =>
        all.where((r) => r.status == s).toList();
    final active = withStatus(RecurringStatus.active);
    final perMonth = active.fold<double>(0, (s, r) => s + monthlyValue(r));

    Widget group(String title, List<RecurringInvoice> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: divided([
                  for (final r in items)
                    RecurringTile(
                        schedule: r, onTap: () => openRecurringDetail(context, r.id)),
                ], l.hairline),
              ),
            ),
          ],
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring invoices')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openRecurringForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New schedule'),
      ),
      body: all.isEmpty
          ? EmptyState(
              icon: Icons.autorenew_rounded,
              title: 'No recurring invoices',
              message: 'Bill retainers, rent or subscriptions automatically: set the '
                  'items once and an invoice is issued on every date.',
              actionLabel: 'New schedule',
              onAction: () => openRecurringForm(context),
            )
          : CenteredListView(
              maxWidth: 760,
              bottom: 96,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active.length == 1
                              ? '1 active schedule bills about'
                              : '${active.length} active schedules bill about',
                          style: text.bodySmall,
                        ),
                        const SizedBox(height: Space.xs),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            MoneyText(perMonth, emphasis: MoneyEmphasis.large),
                            Text(' a month', style: text.bodyMedium?.copyWith(color: l.muted)),
                          ],
                        ),
                        const SizedBox(height: Space.sm),
                        Text(
                          'Invoices are issued when you open the app on or after their date.',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                if (active.isNotEmpty) group('Active', active),
                if (withStatus(RecurringStatus.paused).isNotEmpty)
                  group('Paused', withStatus(RecurringStatus.paused)),
                if (withStatus(RecurringStatus.ended).isNotEmpty)
                  group('Ended', withStatus(RecurringStatus.ended)),
              ],
            ),
    );
  }
}
