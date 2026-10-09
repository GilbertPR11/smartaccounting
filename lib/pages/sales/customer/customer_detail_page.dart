import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/customer/customer_bloc.dart';
import '../../../bloc/estimate/estimate_bloc.dart';
import '../../../bloc/invoice/invoice_bloc.dart';
import '../../../bloc/recurring/recurring_bloc.dart';
import '../../../components/centered_list_view.dart';
import '../../../components/divided.dart';
import '../../../components/estimate_tile.dart';
import '../../../components/initials_avatar.dart';
import '../../../components/invoice_tile.dart';
import '../../../components/money_text.dart';
import '../../../components/recurring_tile.dart';
import '../../../components/section_header.dart';
import '../../../models/estimate_model.dart';
import '../../../models/invoice_model.dart';
import '../../../repository/setting_repository.dart';
import '../../../routes/routes.dart';
import '../../../theme/colors.dart';
import '../../../utils/ledger_summary.dart';
import '../estimate/estimate_flows.dart';
import '../invoice/new_invoice_flow.dart';
import '../recurring/recurring_flows.dart';

/// Everything about one customer: what they owe, and their invoices,
/// estimates and recurring schedules, with shortcuts to create each.
class CustomerDetailPage extends StatefulWidget {
  const CustomerDetailPage({super.key, required this.customerId});

  final String customerId;

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  bool _showPaid = false;

  Future<void> _newInvoice() async {
    final invoice = await Navigator.pushNamed<Invoice>(context, PageRoutes.invoiceForm,
        arguments: InvoiceFormArgs(customerId: widget.customerId));
    if (invoice != null && mounted) await openInvoiceDetail(context, invoice.id);
  }

  @override
  Widget build(BuildContext context) {
    final today = context.read<SettingRepository>().today;
    final customer = context.watch<CustomerBloc>().state.byId(widget.customerId);
    if (customer == null) {
      return const Scaffold(body: Center(child: Text('Customer not found')));
    }
    final invoices = context
        .watch<InvoiceBloc>()
        .state
        .invoices
        .where((i) => i.customerId == customer.id)
        .toList();
    final estimates = context.watch<EstimateBloc>().state.forCustomer(customer.id);
    final schedules = context.watch<RecurringBloc>().state.forCustomer(customer.id);
    final l = context.ledger;
    final text = Theme.of(context).textTheme;

    final open = invoices.where((i) => i.balance > 0.004).toList();
    final paid = invoices.where((i) => i.balance <= 0.004).toList();
    final overdue = LedgerSummary.overdue(invoices, today);
    final openEstimates = estimates
        .where((e) => const {EstimateStatus.pending, EstimateStatus.accepted}
            .contains(e.statusOn(today)))
        .toList();
    final otherEstimates = estimates.where((e) => !openEstimates.contains(e)).toList();
    final contact = [customer.email, customer.phone].where((s) => s.isNotEmpty).toList();

    Widget stat(String label, double value, {Color? color}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
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
          ),
        );

    Widget emptyLine(String message) => Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Text(message, style: text.bodyMedium?.copyWith(color: l.muted)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(customer.name, overflow: TextOverflow.ellipsis)),
      body: CenteredListView(
        maxWidth: 820,
        children: [
          // Who.
          Row(
            children: [
              InitialsAvatar(customer.name, size: 52),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.name, style: text.titleLarge),
                    if (contact.isNotEmpty)
                      Text(contact.join('  ·  '),
                          style: text.bodyMedium?.copyWith(color: l.muted)),
                    if (customer.address.isNotEmpty)
                      Text(customer.address, style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),

          // Money.
          Card(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  stat('Owes you', LedgerSummary.receivable(invoices)),
                  VerticalDivider(width: 1, color: l.hairline),
                  stat(overdue.isEmpty ? 'Overdue' : 'Overdue (${overdue.length})',
                      LedgerSummary.sumBalance(overdue),
                      color: overdue.isEmpty ? null : l.moneyOut),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.md),

          // Shortcuts.
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              FilledButton.icon(
                onPressed: _newInvoice,
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Invoice'),
              ),
              OutlinedButton.icon(
                onPressed: () => openEstimateForm(context, customerId: customer.id),
                icon: const Icon(Icons.request_quote_outlined, size: 18),
                label: const Text('Estimate'),
              ),
              OutlinedButton.icon(
                onPressed: () => openRecurringForm(context, customerId: customer.id),
                icon: const Icon(Icons.autorenew_rounded, size: 18),
                label: const Text('Recurring'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, PageRoutes.statements,
                    arguments: StatementArgs(customerId: customer.id)),
                icon: const Icon(Icons.summarize_outlined, size: 18),
                label: const Text('Statement'),
              ),
            ],
          ),

          // Invoices.
          SectionHeader(
            'Invoices',
            subtitle: open.isEmpty ? null : '${open.length} open',
            action: paid.isEmpty
                ? null
                : TextButton(
                    onPressed: () => setState(() => _showPaid = !_showPaid),
                    child: Text(_showPaid ? 'Hide paid' : 'Show paid (${paid.length})'),
                  ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: (open.isEmpty && !_showPaid)
                ? emptyLine(invoices.isEmpty ? 'No invoices yet.' : 'Everything is paid.')
                : Column(
                    children: divided([
                      for (final inv in [...open, if (_showPaid) ...paid])
                        InvoiceTile(
                            invoice: inv, onTap: () => openInvoiceDetail(context, inv.id)),
                    ], l.hairline),
                  ),
          ),

          // Estimates.
          if (estimates.isNotEmpty) ...[
            SectionHeader('Estimates',
                subtitle: openEstimates.isEmpty ? null : '${openEstimates.length} open'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: divided([
                  for (final e in [...openEstimates, ...otherEstimates])
                    EstimateTile(estimate: e, onTap: () => openEstimateDetail(context, e.id)),
                ], l.hairline),
              ),
            ),
          ],

          // Recurring.
          if (schedules.isNotEmpty) ...[
            const SectionHeader('Recurring invoices'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: divided([
                  for (final r in schedules)
                    RecurringTile(schedule: r, onTap: () => openRecurringDetail(context, r.id)),
                ], l.hairline),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
