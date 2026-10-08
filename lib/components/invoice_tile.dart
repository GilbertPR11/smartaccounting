import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/customer/customer_bloc.dart';
import '../models/invoice_model.dart';
import '../repository/setting_repository.dart';
import '../theme/colors.dart';
import '../utils/format.dart';
import 'initials_avatar.dart';
import 'money_text.dart';
import 'status_chip.dart';

/// One invoice in a list: who, which, when it's due (in words), how much.
class InvoiceTile extends StatelessWidget {
  const InvoiceTile({super.key, required this.invoice, this.onTap, this.selected = false});

  final Invoice invoice;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final customerName = context.select<CustomerBloc, String?>(
            (b) => b.state.byId(invoice.customerId)?.name) ??
        'Unknown customer';
    final today = context.read<SettingRepository>().today;
    final status = invoice.statusOn(today);
    final l = context.ledger;
    final text = Theme.of(context).textTheme;

    final dueText = switch (status) {
      InvoiceStatus.paid => 'Paid in full',
      _ => relativeDue(invoice.dueDate, today),
    };
    final dueColor = status == InvoiceStatus.overdue ? l.moneyOut : l.muted;

    return ListTile(
      onTap: onTap,
      selected: selected,
      leading: InitialsAvatar(customerName),
      title: Text(customerName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text.rich(
        TextSpan(children: [
          TextSpan(text: invoice.number),
          const TextSpan(text: '   '),
          TextSpan(text: dueText, style: TextStyle(color: dueColor)),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MoneyText(
            status == InvoiceStatus.paid ? invoice.total : invoice.balance,
            style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          StatusChip(status),
        ],
      ),
    );
  }
}
