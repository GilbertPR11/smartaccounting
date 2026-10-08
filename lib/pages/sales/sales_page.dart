import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/customer/customer_bloc.dart';
import '../../bloc/invoice/invoice_bloc.dart';
import '../../bloc/product/product_bloc.dart';
import '../../bloc/transaction/transaction_bloc.dart';
import '../../components/centered_list_view.dart';
import '../../components/divided.dart';
import '../../components/initials_avatar.dart';
import '../../components/money_text.dart';
import '../../components/section_header.dart';
import '../../models/invoice_model.dart';
import '../../repository/setting_repository.dart';
import '../../routes/routes.dart';
import '../../theme/colors.dart';
import '../../utils/ledger_summary.dart';
import 'invoice/new_invoice_flow.dart';

/// Sales & payments: a money summary on top, then everything you can do.
class SalesPage extends StatelessWidget {
  const SalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final today = context.read<SettingRepository>().today;
    final invoices = context.watch<InvoiceBloc>().state.invoices;
    final open = invoices.where((i) => i.statusOn(today) != InvoiceStatus.paid).toList();
    final overdue = LedgerSummary.overdue(invoices, today);
    final toInvoice = context.watch<TransactionBloc>().state.invoiceable.length;
    final customerCount = context.watch<CustomerBloc>().state.customers.length;
    final productCount = context.watch<ProductBloc>().state.products.length;
    final l = context.ledger;
    final text = Theme.of(context).textTheme;

    void push(String route) => Navigator.pushNamed(context, route);

    Widget row({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      Widget? trailing,
    }) =>
        ListTile(
          leading: IconBadge(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null) ...[trailing, const SizedBox(width: Space.sm)],
              Icon(Icons.chevron_right, color: l.muted),
            ],
          ),
          onTap: onTap,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Sales & payments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showNewInvoiceSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('New invoice'),
      ),
      body: CenteredListView(
        maxWidth: 760,
        bottom: 96,
        children: [
          // Summary: what's owed, and what's late.
          Card(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Stat(
                      label: open.length == 1 ? '1 open invoice' : '${open.length} open invoices',
                      value: LedgerSummary.receivable(invoices),
                    ),
                  ),
                  VerticalDivider(width: 1, color: l.hairline),
                  Expanded(
                    child: _Stat(
                      label: overdue.isEmpty ? 'Nothing overdue' : '${overdue.length} overdue',
                      value: LedgerSummary.sumBalance(overdue),
                      color: overdue.isEmpty ? null : l.moneyOut,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SectionHeader('Invoicing'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: divided([
                row(
                  icon: Icons.receipt_long_outlined,
                  title: 'Invoices',
                  subtitle: 'View, filter and record payments',
                  trailing: Text('${invoices.length}', style: text.labelLarge),
                  onTap: () => push(PageRoutes.invoices),
                ),
                row(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Invoice from a payment',
                  subtitle: toInvoice == 0
                      ? 'Every payment you received has an invoice'
                      : 'Turn money you received into an invoice',
                  trailing: toInvoice > 0 ? Badge(label: Text('$toInvoice')) : null,
                  onTap: () => openTransactionPicker(context),
                ),
                row(
                  icon: Icons.palette_outlined,
                  title: 'Invoice design',
                  subtitle: 'Logo, colour and what to show',
                  onTap: () => push(PageRoutes.invoiceTemplate),
                ),
              ], l.hairline),
            ),
          ),

          const SectionHeader('Lists'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: divided([
                row(
                  icon: Icons.people_outline,
                  title: 'Customers',
                  subtitle: 'Who you bill',
                  trailing: Text('$customerCount', style: text.labelLarge),
                  onTap: () => push(PageRoutes.customers),
                ),
                row(
                  icon: Icons.inventory_2_outlined,
                  title: 'Products & services',
                  subtitle: 'What you sell, with default price and tax',
                  trailing: Text('$productCount', style: text.labelLarge),
                  onTap: () => push(PageRoutes.products),
                ),
              ], l.hairline),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
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
