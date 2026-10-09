import 'package:flutter/material.dart';

import '../models/estimate_model.dart';
import '../models/invoice_model.dart';
import '../models/recurring_invoice_model.dart';
import '../theme/colors.dart';

/// What a status means, which decides its colour.
enum StatusTone { positive, warning, negative, neutral, accent }

/// A status as a quiet pill with a coloured dot. One look for invoices,
/// bills, estimates and recurring schedules.
class StatusChip extends StatelessWidget {
  /// Invoice or bill status.
  StatusChip(InvoiceStatus status, {super.key})
      : label = status.label,
        tone = switch (status) {
          InvoiceStatus.paid => StatusTone.positive,
          InvoiceStatus.partial => StatusTone.warning,
          InvoiceStatus.overdue => StatusTone.negative,
          InvoiceStatus.unpaid => StatusTone.neutral,
        };

  StatusChip.estimate(EstimateStatus status, {super.key})
      : label = status.label,
        tone = switch (status) {
          EstimateStatus.pending => StatusTone.neutral,
          EstimateStatus.accepted => StatusTone.accent,
          EstimateStatus.converted => StatusTone.positive,
          EstimateStatus.declined => StatusTone.negative,
          EstimateStatus.expired => StatusTone.warning,
        };

  StatusChip.recurring(RecurringStatus status, {super.key})
      : label = status.label,
        tone = switch (status) {
          RecurringStatus.active => StatusTone.positive,
          RecurringStatus.paused => StatusTone.warning,
          RecurringStatus.ended => StatusTone.neutral,
        };

  const StatusChip.custom(this.label, this.tone, {super.key});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final l = context.ledger;
    final color = switch (tone) {
      StatusTone.positive => l.moneyIn,
      StatusTone.warning => l.warning,
      StatusTone.negative => l.moneyOut,
      StatusTone.neutral => l.muted,
      StatusTone.accent => Theme.of(context).colorScheme.primary,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600, height: 1.2)),
        ],
      ),
    );
  }
}
