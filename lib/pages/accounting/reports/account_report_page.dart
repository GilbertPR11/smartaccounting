import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/account/account_bloc.dart';
import '../../../components/money_text.dart';
import '../../../components/period_picker.dart';
import '../../../models/account_model.dart';
import '../../../models/journal_model.dart';
import '../../../repository/setting_repository.dart';
import '../../../theme/colors.dart';
import '../../../utils/format.dart';
import '../../../utils/reports.dart';
import '../accounting_flows.dart';
import '../ledger_scope.dart';
import 'widgets/report_widgets.dart';

/// General ledger for one account: every entry in a period with a running
/// balance. Tapping an entry opens the invoice, bill or transaction behind it.
class AccountReportPage extends StatefulWidget {
  const AccountReportPage({super.key, this.accountId, this.from, this.to});

  final String? accountId;
  final DateTime? from;
  final DateTime? to;

  @override
  State<AccountReportPage> createState() => _AccountReportPageState();
}

class _AccountReportPageState extends State<AccountReportPage> {
  String? _accountId;
  PeriodPreset _preset = PeriodPreset.thisYear;
  late DateTimeRange _range;
  late final DateTime _today;

  @override
  void initState() {
    super.initState();
    _today = context.read<SettingRepository>().today;
    _accountId = widget.accountId;
    final from = widget.from;
    final to = widget.to;
    if (from != null || to != null) {
      _preset = PeriodPreset.custom;
      _range = DateTimeRange(
        start: from ?? DateTime((to ?? _today).year, 1, 1),
        end: to ?? _today,
      );
    } else {
      _range = _preset.rangeFor(_today)!;
    }
  }

  static String _sourceLabel(JournalSource s) => switch (s) {
        JournalSource.manual => 'Journal entry',
        JournalSource.opening => 'Opening balance',
        JournalSource.invoice => 'Invoice',
        JournalSource.invoicePayment => 'Payment received',
        JournalSource.bill => 'Bill',
        JournalSource.billPayment => 'Bill payment',
        JournalSource.transaction => 'Transaction',
      };

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AccountBloc>().state;
    final ledger = watchLedger(context);
    final account = accounts.byId(_accountId) ?? (accounts.active.isEmpty ? null : accounts.active.first);
    final text = Theme.of(context).textTheme;
    final l = context.ledger;

    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: account?.id,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Account'),
          items: [
            for (final type in AccountType.values)
              for (final a in accounts.accounts.where((a) => a.type == type))
                DropdownMenuItem(
                  value: a.id,
                  child: Text('${type.label} · ${a.display}${a.archived ? ' (archived)' : ''}',
                      overflow: TextOverflow.ellipsis),
                ),
          ],
          onChanged: (v) => setState(() => _accountId = v),
        ),
        const SizedBox(height: Space.md),
        PeriodPicker(
          preset: _preset,
          range: _range,
          today: _today,
          onChanged: (p, r) => setState(() {
            _preset = p;
            _range = r;
          }),
        ),
      ],
    );

    if (account == null) {
      return ReportScaffold(title: 'Account transactions', controls: controls, children: const [
        ReportEmpty('No accounts yet.'),
      ]);
    }
    final activity = accountActivity(ledger, account, _range.start, _range.end);
    final sign = account.type.debitNormal ? 1 : -1;

    return ReportScaffold(
      title: account.name,
      subtitle: '${account.type.label} · ${fmtDate(_range.start)} – ${fmtDate(_range.end)}',
      controls: controls,
      children: [
        ReportLine('Starting balance', activity.opening),
        Divider(height: 1, color: l.hairline),
        if (activity.lines.isEmpty) const ReportEmpty('Nothing posted in this period.'),
        for (final line in activity.lines)
          InkWell(
            onTap: () => openEntrySource(context, line.entry),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.entry.description,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                        Text('${fmtDate(line.entry.date)} · ${_sourceLabel(line.entry.source)}',
                            style: text.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      MoneyText(round2(sign * (line.debit - line.credit)), showSign: true),
                      MoneyText(line.balance, style: text.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ReportTotal('Ending balance', activity.closing),
      ],
    );
  }
}
