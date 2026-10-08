import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/vendor/vendor_bloc.dart';
import '../models/bill_model.dart';
import '../models/invoice_model.dart';
import '../repository/setting_repository.dart';
import '../theme/colors.dart';
import '../utils/format.dart';
import 'initials_avatar.dart';
import 'money_text.dart';
import 'status_chip.dart';

/// One bill in a list: who you owe, their reference, when it's due, how much.
class BillTile extends StatelessWidget {
  const BillTile({super.key, required this.bill, this.onTap, this.selected = false});

  final Bill bill;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final vendorName =
        context.select<VendorBloc, String?>((b) => b.state.byId(bill.vendorId)?.name) ??
            'Unknown vendor';
    final today = context.read<SettingRepository>().today;
    final status = bill.statusOn(today);
    final l = context.ledger;

    final dueText = status == InvoiceStatus.paid ? 'Paid' : relativeDue(bill.dueDate, today);
    return ListTile(
      onTap: onTap,
      selected: selected,
      leading: InitialsAvatar(vendorName),
      title: Text(vendorName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text.rich(
        TextSpan(children: [
          if (bill.number.isNotEmpty) ...[TextSpan(text: bill.number), const TextSpan(text: '   ')],
          TextSpan(
            text: dueText,
            style: TextStyle(color: status == InvoiceStatus.overdue ? l.moneyOut : l.muted),
          ),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MoneyText(status == InvoiceStatus.paid ? bill.total : bill.balance),
          const SizedBox(height: 4),
          StatusChip(status),
        ],
      ),
    );
  }
}
