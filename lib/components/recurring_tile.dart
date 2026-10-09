import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/customer/customer_bloc.dart';
import '../models/recurring_invoice_model.dart';
import '../theme/colors.dart';
import '../utils/format.dart';
import 'initials_avatar.dart';
import 'money_text.dart';
import 'status_chip.dart';

/// One recurring schedule: who, how often, when next, how much each time.
class RecurringTile extends StatelessWidget {
  const RecurringTile({super.key, required this.schedule, this.onTap, this.selected = false});

  final RecurringInvoice schedule;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final customerName = context.select<CustomerBloc, String?>(
            (b) => b.state.byId(schedule.customerId)?.name) ??
        'Unknown customer';
    final l = context.ledger;
    final text = Theme.of(context).textTheme;
    final next = schedule.nextDate;
    final when = switch (schedule.status) {
      RecurringStatus.paused => 'Paused',
      RecurringStatus.active => next == null ? '' : 'Next ${fmtDateShort(next)}',
      RecurringStatus.ended => '${schedule.issuedCount} issued',
    };

    return ListTile(
      onTap: onTap,
      selected: selected,
      leading: InitialsAvatar(customerName),
      title: Text(customerName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${schedule.frequency.label}   $when',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: l.muted)),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MoneyText(schedule.total,
              style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          StatusChip.recurring(schedule.status),
        ],
      ),
    );
  }
}
