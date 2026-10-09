import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/bill/bill_bloc.dart';
import '../../../bloc/invoice/invoice_bloc.dart';
import '../../../components/period_picker.dart';
import '../../../repository/setting_repository.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import '../../../utils/reports.dart';
import 'widgets/report_widgets.dart';

/// SST charged to customers in a period (what you owe the tax authority),
/// with SST paid on bills for reference.
class SstReportPage extends StatefulWidget {
  const SstReportPage({super.key});

  @override
  State<SstReportPage> createState() => _SstReportPageState();
}

class _SstReportPageState extends State<SstReportPage> {
  PeriodPreset _preset = PeriodPreset.thisQuarter;
  late DateTimeRange _range;
  late final DateTime _today;

  @override
  void initState() {
    super.initState();
    _today = context.read<SettingRepository>().today;
    _range = _preset.rangeFor(_today)!;
  }

  @override
  Widget build(BuildContext context) {
    final report = sstReport(
      context.watch<InvoiceBloc>().state.invoices,
      context.watch<BillBloc>().state.bills,
      _range.start,
      _range.end,
    );
    final text = Theme.of(context).textTheme;

    List<Widget> rows(List<TaxRow> items, String empty) => [
          if (items.isEmpty) ReportEmpty(empty),
          for (final r in items)
            ReportLine('${r.label} on ${money(r.taxable)}', r.tax),
        ];

    return ReportScaffold(
      title: 'SST summary',
      subtitle: '${fmtDate(_range.start)} – ${fmtDate(_range.end)} · by invoice date',
      controls: PeriodPicker(
        preset: _preset,
        range: _range,
        today: _today,
        onChanged: (p, r) => setState(() {
          _preset = p;
          _range = r;
        }),
      ),
      children: [
        const ReportHeading('Charged to customers'),
        ...rows(report.charged, 'No SST charged in this period.'),
        ReportTotal('SST to pay', report.totalCharged, large: true),
        const ReportHeading('Paid on bills'),
        ...rows(report.paid, 'No SST on bills in this period.'),
        ReportTotal('SST paid (part of your costs)', report.totalPaid),
        const SizedBox(height: Space.md),
        Text(
          'Service tax paid on purchases generally can\'t be claimed back, so it isn\'t '
          'deducted here. Check your SST-02 return with your tax agent.',
          style: text.bodySmall,
        ),
      ],
    );
  }
}
