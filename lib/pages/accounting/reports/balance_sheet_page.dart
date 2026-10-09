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

/// What the business owns and owes on a date.
class BalanceSheetPage extends StatefulWidget {
  const BalanceSheetPage({super.key});

  @override
  State<BalanceSheetPage> createState() => _BalanceSheetPageState();
}

class _BalanceSheetPageState extends State<BalanceSheetPage> {
  late DateTime _asOf;

  @override
  void initState() {
    super.initState();
    _asOf = context.read<SettingRepository>().today;
  }

  void _open(Account a) => Navigator.pushNamed(context, PageRoutes.reportAccount,
      arguments: AccountReportArgs(a.id, from: DateTime(_asOf.year, 1, 1), to: _asOf));

  List<Widget> _section(String title, List<ReportRow> rows, String empty) => [
        ReportHeading(title),
        if (rows.isEmpty) ReportEmpty(empty),
        for (final r in rows)
          ReportLine(r.account.name, r.amount, secondary: r.account.code, onTap: () => _open(r.account)),
      ];

  @override
  Widget build(BuildContext context) {
    final report = balanceSheet(watchLedger(context), _asOf);
    final l = context.ledger;
    return ReportScaffold(
      title: 'Balance sheet',
      subtitle: 'As of ${fmtDate(_asOf)}',
      controls: Row(
        children: [
          AsOfPicker(date: _asOf, onChanged: (d) => setState(() => _asOf = d)),
          const Spacer(),
          if (!report.balances)
            Text('Out of balance', style: TextStyle(color: l.moneyOut)),
        ],
      ),
      children: [
        ..._section('Assets', report.assets, 'No assets.'),
        ReportTotal('Total assets', report.totalAssets),
        ..._section('Liabilities', report.liabilities, 'No liabilities.'),
        ReportTotal('Total liabilities', report.totalLiabilities),
        ..._section('Equity', report.equity, 'No owner equity yet.'),
        ReportLine('Profit to date (retained earnings)', report.profitToDate),
        ReportTotal('Total equity', report.totalEquity),
        const SizedBox(height: Space.md),
        ReportTotal('Liabilities + equity', report.totalLiabilitiesAndEquity, large: true),
      ],
    );
  }
}
