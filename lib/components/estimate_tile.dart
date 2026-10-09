import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/customer/customer_bloc.dart';
import '../models/estimate_model.dart';
import '../repository/setting_repository.dart';
import '../theme/colors.dart';
import '../utils/format.dart';
import 'initials_avatar.dart';
import 'money_text.dart';
import 'status_chip.dart';

/// One estimate in a list: who, which, how long it's valid, how much.
class EstimateTile extends StatelessWidget {
  const EstimateTile({super.key, required this.estimate, this.onTap, this.selected = false});

  final Estimate estimate;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final customerName = context.select<CustomerBloc, String?>(
            (b) => b.state.byId(estimate.customerId)?.name) ??
        'Unknown customer';
    final today = context.read<SettingRepository>().today;
    final status = estimate.statusOn(today);
    final l = context.ledger;
    final text = Theme.of(context).textTheme;

    final when = switch (status) {
      EstimateStatus.pending || EstimateStatus.expired =>
        relativeExpiry(estimate.expiryDate, today),
      _ => 'Sent ${fmtDateShort(estimate.issueDate)}',
    };

    return ListTile(
      onTap: onTap,
      selected: selected,
      leading: InitialsAvatar(customerName),
      title: Text(customerName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text.rich(
        TextSpan(children: [
          TextSpan(text: estimate.number),
          const TextSpan(text: '   '),
          TextSpan(
              text: when,
              style: TextStyle(color: status == EstimateStatus.expired ? l.warning : l.muted)),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MoneyText(estimate.total,
              style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          StatusChip.estimate(status),
        ],
      ),
    );
  }
}
