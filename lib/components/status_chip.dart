import 'package:flutter/material.dart';

import '../models/invoice_model.dart';
import '../theme/colors.dart';

/// Invoice status as a quiet pill with a coloured dot.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final l = context.ledger;
    final color = switch (status) {
      InvoiceStatus.paid => l.moneyIn,
      InvoiceStatus.partial => l.warning,
      InvoiceStatus.overdue => l.moneyOut,
      InvoiceStatus.unpaid => l.muted,
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
          Text(status.label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600, height: 1.2)),
        ],
      ),
    );
  }
}
