import 'package:flutter/material.dart';

import '../../../components/centered_list_view.dart';
import '../../../components/divided.dart';
import '../../../components/initials_avatar.dart';
import '../../../components/section_header.dart';
import '../../../routes/routes.dart';
import '../../../theme/colors.dart';

/// Every report, grouped like Wave's Reports page.
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.ledger;
    final scheme = Theme.of(context).colorScheme;

    Widget row(IconData icon, String title, String subtitle, String route, {Object? args}) =>
        ListTile(
          leading: IconBadge(icon, color: scheme.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: Icon(Icons.chevron_right, color: l.muted),
          onTap: () => Navigator.pushNamed(context, route, arguments: args),
        );

    Widget group(String title, List<Widget> rows) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title),
            Card(clipBehavior: Clip.antiAlias, child: Column(children: divided(rows, l.hairline))),
          ],
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: CenteredListView(
        maxWidth: 760,
        children: [
          group('Financial statements', [
            row(Icons.trending_up_rounded, 'Profit & loss',
                'Income minus expenses for a period', PageRoutes.reportProfitLoss),
            row(Icons.account_balance_outlined, 'Balance sheet',
                'What you own and owe on a date', PageRoutes.reportBalanceSheet),
          ]),
          group('Customers & vendors', [
            row(Icons.call_received_rounded, 'Aged receivables',
                'Who owes you, and how late', PageRoutes.reportAgedReceivables),
            row(Icons.call_made_rounded, 'Aged payables',
                'Who you owe, and how late', PageRoutes.reportAgedPayables),
          ]),
          group('Tax', [
            row(Icons.percent_rounded, 'SST summary',
                'SST charged and paid in a period', PageRoutes.reportSst),
          ]),
          group('Detailed reporting', [
            row(Icons.list_alt_rounded, 'Account transactions',
                'Every entry in one account (general ledger)', PageRoutes.reportAccount),
            row(Icons.balance_rounded, 'Trial balance',
                'Debit and credit balance of every account', PageRoutes.reportTrialBalance),
          ]),
        ],
      ),
    );
  }
}
