import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/bill/bill_bloc.dart';
import '../../../bloc/customer/customer_bloc.dart';
import '../../../bloc/invoice/invoice_bloc.dart';
import '../../../bloc/vendor/vendor_bloc.dart';
import '../../../components/money_text.dart';
import '../../../repository/setting_repository.dart';
import '../../../routes/routes.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import '../../../utils/reports.dart';
import 'widgets/report_widgets.dart';

/// Aged receivables (customers) or aged payables (vendors), as of today.
class AgingReportPage extends StatelessWidget {
  const AgingReportPage({super.key, required this.payables});

  /// True for what you owe vendors; false for what customers owe you.
  final bool payables;

  @override
  Widget build(BuildContext context) {
    final today = context.read<SettingRepository>().today;
    final customers = context.watch<CustomerBloc>().state;
    final vendors = context.watch<VendorBloc>().state;
    final report = payables
        ? agedPayables(context.watch<BillBloc>().state.bills, today)
        : agedReceivables(context.watch<InvoiceBloc>().state.invoices, today);
    final text = Theme.of(context).textTheme;
    final l = context.ledger;
    final totals = report.columnTotals;

    String name(String id) => payables
        ? (vendors.byId(id)?.name ?? 'Unknown vendor')
        : (customers.byId(id)?.name ?? 'Unknown customer');

    return ReportScaffold(
      title: payables ? 'Aged payables' : 'Aged receivables',
      subtitle: 'As of ${fmtDate(today)}',
      controls: Text(
        payables
            ? 'Unpaid bills, grouped by how far past their due date they are.'
            : 'Unpaid invoices, grouped by how far past their due date they are.',
        style: text.bodyMedium,
      ),
      children: [
        // Summary by bucket, then each party with its own breakdown.
        for (var i = 0; i < agingBuckets.length; i++)
          ReportLine(agingBuckets[i] == agingBuckets.first ? agingBuckets[i] : '${agingBuckets[i]} overdue',
              totals[i]),
        ReportTotal(payables ? 'Total you owe' : 'Total owed to you', report.total, large: true),
        ReportHeading(payables ? 'By vendor' : 'By customer'),
        if (report.rows.isEmpty)
          ReportEmpty(payables ? 'Every bill is paid.' : 'Every invoice is paid.'),
        for (final row in report.rows)
          InkWell(
            onTap: payables
                ? () => Navigator.pushNamed(context, PageRoutes.bills,
                    arguments: BillListArgs(vendorId: row.partyId))
                : () => Navigator.pushNamed(context, PageRoutes.customerDetail,
                    arguments: row.partyId),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name(row.partyId),
                            style: text.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary)),
                      ),
                      MoneyText(row.total,
                          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Text(
                    [
                      for (var i = 0; i < agingBuckets.length; i++)
                        if (row.amounts[i] > 0) '${agingBuckets[i]}: ${money(row.amounts[i])}',
                    ].join('  ·  '),
                    style: text.bodySmall?.copyWith(color: row.amounts.skip(1).any((a) => a > 0) ? l.moneyOut : null),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
