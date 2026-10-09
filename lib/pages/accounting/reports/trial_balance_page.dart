import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../components/money_text.dart';
import '../../../components/period_picker.dart';
import '../../../repository/setting_repository.dart';
import '../../../routes/routes.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import '../../../utils/reports.dart';
import '../ledger_scope.dart';
import 'widgets/report_widgets.dart';

/// Every account's debit or credit balance. The two columns must agree.
class TrialBalancePage extends StatefulWidget {
  const TrialBalancePage({super.key});

  @override
  State<TrialBalancePage> createState() => _TrialBalancePageState();
}

class _TrialBalancePageState extends State<TrialBalancePage> {
  late DateTime _asOf;

  @override
  void initState() {
    super.initState();
    _asOf = context.read<SettingRepository>().today;
  }

  @override
  Widget build(BuildContext context) {
    final report = trialBalance(watchLedger(context), _asOf);
    final text = Theme.of(context).textTheme;
    final l = context.ledger;
    final head = text.labelMedium?.copyWith(color: l.muted);
    final bold = text.bodyMedium?.copyWith(fontWeight: FontWeight.w700);

    Widget row(Widget label, Widget debit, Widget credit, {VoidCallback? onTap}) {
      final r = Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(child: label),
            SizedBox(width: 120, child: Align(alignment: Alignment.centerRight, child: debit)),
            SizedBox(width: 120, child: Align(alignment: Alignment.centerRight, child: credit)),
          ],
        ),
      );
      return onTap == null ? r : InkWell(onTap: onTap, child: r);
    }

    return ReportScaffold(
      title: 'Trial balance',
      subtitle: 'As of ${fmtDate(_asOf)}',
      controls: Align(
        alignment: Alignment.centerLeft,
        child: AsOfPicker(date: _asOf, onChanged: (d) => setState(() => _asOf = d)),
      ),
      children: [
        row(Text('ACCOUNT', style: head), Text('DEBIT', style: head), Text('CREDIT', style: head)),
        Divider(height: 1, color: l.hairline),
        for (final r in report.rows)
          row(
            Text(r.account.display, style: text.bodyMedium),
            r.debit > 0 ? MoneyText(r.debit) : const SizedBox(),
            r.credit > 0 ? MoneyText(r.credit) : const SizedBox(),
            onTap: () => Navigator.pushNamed(context, PageRoutes.reportAccount,
                arguments: AccountReportArgs(r.account.id, to: _asOf)),
          ),
        Divider(height: 1, color: l.hairline),
        row(Text('Total', style: bold), MoneyText(report.totalDebit, style: bold),
            MoneyText(report.totalCredit, style: bold)),
      ],
    );
  }
}
