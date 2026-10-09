import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/bill/bill_bloc.dart';
import '../../bloc/customer/customer_bloc.dart';
import '../../bloc/invoice/invoice_bloc.dart';
import '../../bloc/setting/setting_bloc.dart';
import '../../bloc/receipt/receipt_bloc.dart';
import '../../bloc/transaction/transaction_bloc.dart';
import '../../bloc/vendor/vendor_bloc.dart';
import '../../components/divided.dart';
import '../../components/initials_avatar.dart';
import '../../components/invoice_tile.dart';
import '../../components/money_text.dart';
import '../../components/section_header.dart';
import '../../config/layout.dart';
import '../../repository/setting_repository.dart';
import '../../routes/routes.dart';
import '../../theme/colors.dart';
import '../../utils/format.dart';
import '../../utils/ledger_summary.dart';
import '../purchases/purchase_flows.dart';
import '../sales/invoice/new_invoice_flow.dart';
import 'widgets/balance_sparkline.dart';
import 'widgets/cash_flow_chart.dart';
import '../home/app_shell.dart';

/// The first screen: where your cash stands, and what needs doing.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingRepository>();
    final businessName = context.watch<SettingBloc>().state.profile.name;
    final invoices = context.watch<InvoiceBloc>().state.invoices;
    final txnState = context.watch<TransactionBloc>().state;
    final customers = context.watch<CustomerBloc>().state;
    final txns = txnState.transactions;
    final today = settings.today;
    final l = context.ledger;
    final text = Theme.of(context).textTheme;

    final cash = LedgerSummary.cashBalance(settings.openingBalance, txns);
    final series = LedgerSummary.balanceSeries(settings.openingBalance, txns, today, 90);
    final netMonth = LedgerSummary.netThisMonth(txns, today);
    final receivable = LedgerSummary.receivable(invoices);
    final overdue = LedgerSummary.overdue(invoices, today)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final overdueAmount = LedgerSummary.sumBalance(overdue);
    final months = LedgerSummary.monthly(txns, today, 6);
    final recent = invoices.take(5).toList();
    final uninvoiced = txnState.invoiceable;
    final billsDue = LedgerSummary.billsDueSoon(context.watch<BillBloc>().state.bills, today);
    final vendors = context.watch<VendorBloc>().state;
    final receiptsToReview = context.watch<ReceiptBloc>().state.toReview.length;

    // ------------------------------------------------------------ pieces

    final menuButton = AppShell.menuButton(context);
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (menuButton != null) ...[
          Padding(padding: const EdgeInsets.only(bottom: Space.xs), child: menuButton),
          const SizedBox(width: Space.xs),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(businessName,
                  style: text.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: Space.xs),
              Text(greetingFor(DateTime.now()), style: text.headlineSmall),
              Text(fmtLongDate(today), style: text.bodyMedium?.copyWith(color: l.muted)),
            ],
          ),
        ),
        const SizedBox(width: Space.md),
        FilledButton.icon(
          onPressed: () => showNewInvoiceSheet(context),
          icon: const Icon(Icons.add, size: 20),
          label: const Text('New invoice'),
        ),
      ],
    );

    final cashBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cash across ${settings.accounts.length} accounts',
            style: text.bodyMedium?.copyWith(color: l.muted)),
        const SizedBox(height: Space.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: MoneyText(cash, emphasis: MoneyEmphasis.hero),
        ),
        const SizedBox(height: Space.xs),
        Row(
          children: [
            Icon(netMonth >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 18, color: netMonth >= 0 ? l.moneyIn : l.moneyOut),
            const SizedBox(width: 6),
            MoneyText(netMonth,
                showSign: true,
                color: netMonth >= 0 ? l.moneyIn : l.moneyOut,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            Flexible(
              child: Text(' this month',
                  style: text.bodyMedium?.copyWith(color: l.muted),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        BalanceSparkline(values: series, height: 84),
        const SizedBox(height: Space.xs),
        Row(
          children: [
            Text('90 days ago', style: text.labelSmall),
            const Spacer(),
            Text('Today', style: text.labelSmall),
          ],
        ),
      ],
    );

    final kpis = Card(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _Kpi(label: 'Owed to you', value: receivable)),
            VerticalDivider(width: 1, color: l.hairline),
            Expanded(
              child: _Kpi(
                label: overdue.isEmpty ? 'Overdue' : 'Overdue (${overdue.length})',
                value: overdueAmount,
                color: overdueAmount > 0 ? l.moneyOut : null,
              ),
            ),
            VerticalDivider(width: 1, color: l.hairline),
            Expanded(
              child: _Kpi(
                label: 'Net this month',
                value: netMonth,
                color: netMonth >= 0 ? l.moneyIn : l.moneyOut,
              ),
            ),
          ],
        ),
      ),
    );

    final attentionItems = <Widget>[
      for (final inv in overdue.take(3))
        ListTile(
          leading: InitialsAvatar(customers.byId(inv.customerId)?.name ?? '?'),
          title: Text(customers.byId(inv.customerId)?.name ?? 'Unknown customer',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${inv.number} is ${relativeDue(inv.dueDate, today)}',
              style: TextStyle(color: l.moneyOut)),
          trailing: MoneyText(inv.balance),
          onTap: () => openInvoiceDetail(context, inv.id),
        ),
      for (final b in billsDue.take(2))
        ListTile(
          leading: InitialsAvatar(vendors.byId(b.vendorId)?.name ?? '?'),
          title: Text('Pay ${vendors.byId(b.vendorId)?.name ?? 'vendor'}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            relativeDue(b.dueDate, today),
            style: TextStyle(color: b.dueDate.isBefore(today) ? l.moneyOut : l.warning),
          ),
          trailing: MoneyText(b.balance),
          onTap: () => openBillDetail(context, b.id),
        ),
      if (receiptsToReview > 0)
        ListTile(
          leading: IconBadge(Icons.document_scanner_outlined, color: l.warning),
          title: Text(receiptsToReview == 1
              ? '1 receipt to review'
              : '$receiptsToReview receipts to review'),
          subtitle: const Text('Record them so your spending is up to date'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, PageRoutes.receipts),
        ),
      if (uninvoiced.isNotEmpty)
        ListTile(
          leading: IconBadge(Icons.receipt_long_outlined,
              color: Theme.of(context).colorScheme.primary),
          title: Text(uninvoiced.length == 1
              ? '1 payment has no invoice'
              : '${uninvoiced.length} payments have no invoice'),
          subtitle: const Text('Create invoices for your records'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openTransactionPicker(context),
        ),
    ];

    final attention = attentionItems.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader('Needs attention'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(children: divided(attentionItems, l.hairline)),
              ),
            ],
          );

    final cashFlow = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Money in and out', subtitle: 'Last 6 months'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.md),
            child: CashFlowChart(months: months),
          ),
        ),
      ],
    );

    final recentSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Recent invoices',
          action: TextButton(
            onPressed: () => Navigator.pushNamed(context, PageRoutes.invoices),
            child: const Text('See all'),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: recent.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(Space.xl),
                  child: Text('Invoices you create will appear here.',
                      style: text.bodyMedium?.copyWith(color: l.muted)),
                )
              : Column(
                  children: divided([
                    for (final inv in recent)
                      InvoiceTile(
                          invoice: inv, onTap: () => openInvoiceDetail(context, inv.id)),
                  ], l.hairline),
                ),
        ),
      ],
    );

    // ------------------------------------------------------------ layout

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= Breakpoints.twoPane;
          final pad = sidePadding(c.maxWidth, maxWidth: 1200, min: Space.lg);

          final children = wide
              ? <Widget>[
                  header,
                  const SizedBox(height: Space.xl),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            cashBlock,
                            const SizedBox(height: Space.xl),
                            kpis,
                            cashFlow,
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.xl),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (attention != null) attention,
                            recentSection,
                          ],
                        ),
                      ),
                    ],
                  ),
                ]
              : <Widget>[
                  header,
                  const SizedBox(height: Space.xl),
                  cashBlock,
                  const SizedBox(height: Space.xl),
                  kpis,
                  if (attention != null) attention,
                  cashFlow,
                  recentSection,
                ];

          return ListView(
            padding: EdgeInsets.fromLTRB(pad, Space.lg, pad, Space.xxl),
            children: children,
          );
        }),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, this.color});

  final String label;
  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: Space.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyText(value, color: color, emphasis: MoneyEmphasis.large),
          ),
        ],
      ),
    );
  }
}
