import 'package:flutter/material.dart';

import '../../../../models/transaction_model.dart';
import '../../../../components/initials_avatar.dart';
import '../../../../components/money_text.dart';
import '../../../../theme/colors.dart';
import '../../../../utils/format.dart';
import '../../widgets/document_form_parts.dart';

// Invoice-only parts of the invoice form (creating from a payment).
// Parts shared with estimates and recurring invoices live in
// pages/sales/widgets/document_form_parts.dart.


class SourceBanner extends StatelessWidget {
  const SourceBanner({super.key, required this.txn});

  final BankTransaction txn;

  @override
  Widget build(BuildContext context) {
    final l = context.ledger;
    return Card(
      child: ListTile(
        leading: IconBadge(Icons.south_west_rounded, color: l.moneyIn),
        title: Text('Received ${fmtDate(txn.date)} into ${txn.account}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(txn.description, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: MoneyText(txn.amount, color: l.moneyIn),
      ),
    );
  }
}

class ReconciliationBox extends StatelessWidget {
  const ReconciliationBox({
    super.key,
    required this.txnAmount,
    required this.invoiceTotal,
    required this.onMatch,
  });

  final double txnAmount;
  final double invoiceTotal;
  final VoidCallback onMatch;

  @override
  Widget build(BuildContext context) {
    final diff = round2(invoiceTotal - txnAmount);
    final matched = diff.abs() < 0.005;
    final l = context.ledger;

    final (Color bg, Color fg, IconData icon, String msg) = matched
        ? (l.moneyIn.withOpacity(0.10), l.moneyIn, Icons.check_circle_outline,
            'Matches the transaction. Invoice will be marked paid.')
        : diff > 0
            ? (l.warning.withOpacity(0.10), l.warning, Icons.info_outline,
                '${money(diff)} more than received. Invoice will be partially '
                    'paid with ${money(diff)} still due.')
            : (l.moneyOut.withOpacity(0.10), l.moneyOut, Icons.warning_amber_rounded,
                '${money(-diff)} less than received. The excess payment will '
                    'stay unapplied.');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.control)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TotalRow('Transaction amount', money(txnAmount), color: fg),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Expanded(child: Text(msg, style: TextStyle(color: fg, fontSize: 13))),
            ],
          ),
          if (!matched) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onMatch,
                style: TextButton.styleFrom(foregroundColor: fg),
                child: const Text('Adjust prices to match (tax-inclusive)'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
