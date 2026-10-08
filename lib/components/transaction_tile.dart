import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/invoice/invoice_bloc.dart';
import '../models/transaction_model.dart';
import '../theme/colors.dart';
import '../utils/format.dart';
import 'initials_avatar.dart';
import 'money_text.dart';

/// One bank/cash movement. Money in is green with "+", money out is plain.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.trailing,
    this.selected = false,
  });

  final BankTransaction transaction;
  final VoidCallback? onTap;

  /// Replaces the default signed amount.
  final Widget? trailing;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final l = context.ledger;
    final invoiceNumber = context.select<InvoiceBloc, String?>(
        (b) => b.state.byId(t.invoiceId)?.number);
    final text = Theme.of(context).textTheme;

    return ListTile(
      onTap: onTap,
      selected: selected,
      leading: IconBadge(
        t.isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
        color: t.isIncome ? l.moneyIn : l.muted,
      ),
      title: Text(t.description, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text.rich(
        TextSpan(children: [
          TextSpan(text: fmtDateShort(t.date)),
          const TextSpan(text: '   '),
          TextSpan(text: t.category),
          if (invoiceNumber != null) ...[
            const TextSpan(text: '   '),
            TextSpan(
                text: invoiceNumber,
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ],
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing ??
          MoneyText(
            t.isIncome ? t.amount : -t.amount,
            showSign: true,
            color: t.isIncome ? l.moneyIn : null,
            style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
    );
  }
}
