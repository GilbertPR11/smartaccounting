import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../components/period_picker.dart';
import '../../../models/account_model.dart';
import '../../../repository/setting_repository.dart';
import '../../../routes/routes.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import '../../../utils/reports.dart';
import '../ledger_scope.dart';
import 'widgets/report_widgets.dart';

/// Income minus expenses for a period (accrual basis).
class ProfitLossPage extends StatefulWidget {
  const ProfitLossPage({super.key});

  @override
  State<ProfitLossPage> createState() => _ProfitLossPageState();
}

class _ProfitLossPageState extends State<ProfitLossPage> {
  PeriodPreset _preset = PeriodPreset.thisYear;
  late DateTimeRange _range;
  late final DateTime _today;

  @override
  void initState() {
    super.initState();
    _today = context.read<SettingRepository>().today;
    _range = _preset.rangeFor(_today)!;
  }

  void _open(Account a) => Navigator.pushNamed(context, PageRoutes.reportAccount,
      arguments: AccountReportArgs(a.id, from: _range.start, to: _range.end));

  @override
  Widget build(BuildContext context) {
    final report = profitAndLoss(watchLedger(context), _range.start, _range.end);
    final l = context.ledger;
    return ReportScaffold(
      title: 'Profit & loss',
      subtitle: '${fmtDate(_range.start)} – ${fmtDate(_range.end)} · accrual basis',
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
        const ReportHeading('Income'),
        if (report.income.isEmpty) const ReportEmpty('No income in this period.'),
        for (final r in report.income)
          ReportLine(r.account.name, r.amount, secondary: r.account.code, onTap: () => _open(r.account)),
        ReportTotal('Total income', report.totalIncome),
        const ReportHeading('Expenses'),
        if (report.expenses.isEmpty) const ReportEmpty('No expenses in this period.'),
        for (final r in report.expenses)
          ReportLine(r.account.name, r.amount, secondary: r.account.code, onTap: () => _open(r.account)),
        ReportTotal('Total expenses', report.totalExpenses),
        const SizedBox(height: Space.md),
        ReportTotal(
          report.netProfit >= 0 ? 'Net profit' : 'Net loss',
          report.netProfit,
          large: true,
          color: report.netProfit >= 0 ? l.moneyIn : l.moneyOut,
        ),
      ],
    );
  }
}
