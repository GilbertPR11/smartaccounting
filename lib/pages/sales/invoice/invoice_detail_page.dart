import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/customer/customer_bloc.dart';
import '../../../bloc/estimate/estimate_bloc.dart';
import '../../../bloc/invoice/invoice_bloc.dart';
import '../../../bloc/recurring/recurring_bloc.dart';
import '../../../bloc/setting/setting_bloc.dart';
import '../../../bloc/transaction/transaction_bloc.dart';
import '../../../components/centered_list_view.dart';
import '../../../components/initials_avatar.dart';
import '../../../components/invoice_document.dart';
import '../../../components/section_header.dart';
import '../../../components/status_chip.dart';
import '../../../components/transaction_tile.dart';
import '../../../config/constants.dart';
import '../../../models/invoice_model.dart';
import '../../../repository/setting_repository.dart';
import '../../../routes/routes.dart';
import '../../../utils/format.dart';
import '../estimate/estimate_flows.dart';
import '../recurring/recurring_flows.dart';

class InvoiceDetailPage extends StatefulWidget {
  const InvoiceDetailPage({
    super.key,
    required this.invoiceId,
    this.justCreated = false,
    this.embedded = false,
  });

  final String invoiceId;
  final bool justCreated;

  /// True when shown as the right-hand pane of a list/detail layout.
  final bool embedded;

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  @override
  void initState() {
    super.initState();
    if (widget.justCreated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final inv = context.read<InvoiceBloc>().state.byId(widget.invoiceId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${inv?.number ?? 'Invoice'} created')),
        );
      });
    }
  }

  Future<void> _recordPayment(Invoice inv) async {
    final accounts = context.read<SettingRepository>().accounts;
    final amount = TextEditingController(text: inv.balance.toStringAsFixed(2));
    var account = accounts.first;
    final key = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Record payment'),
          content: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amount,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Amount', prefixText: '${Constants.currency} '),
                  validator: (v) {
                    final n = parseAmount(v ?? '');
                    if (n == null || n <= 0) return 'Enter an amount';
                    if (n > inv.balance + 0.004) {
                      return 'Max ${money(inv.balance)}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: account,
                  decoration: const InputDecoration(labelText: 'Deposit to'),
                  items: [
                    for (final a in accounts)
                      DropdownMenuItem(value: a, child: Text(a)),
                  ],
                  onChanged: (v) => setLocal(() => account = v ?? account),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    context.read<InvoiceBloc>().add(RecordInvoicePayment(
          invoiceId: inv.id,
          amount: parseAmount(amount.text)!,
          date: context.read<SettingRepository>().today,
          account: account,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingRepository>();
    final inv = context.watch<InvoiceBloc>().state.byId(widget.invoiceId);
    if (inv == null) {
      return const Scaffold(body: Center(child: Text('Invoice not found')));
    }
    final customer = context.watch<CustomerBloc>().state.byId(inv.customerId);
    final settingState = context.watch<SettingBloc>().state;
    final txnState = context.watch<TransactionBloc>().state;
    final status = inv.statusOn(settings.today);
    final source = txnState.byId(inv.sourceTransactionId);
    final payments = txnState.paymentsFor(inv.id, excludeId: inv.sourceTransactionId);
    final scheme = Theme.of(context).colorScheme;
    final estimate = context.watch<EstimateBloc>().state.byId(inv.estimateId);
    final schedule = context.watch<RecurringBloc>().state.byId(inv.recurringId);

    return BlocListener<InvoiceBloc, InvoiceState>(
      listenWhen: (prev, next) => next.error != null && prev.error != next.error,
      listener: (context, state) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(state.error!))),
      child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(inv.number),
        actions: [
          IconButton(
            tooltip: 'Share PDF',
            icon: const Icon(Icons.ios_share),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PDF export & sending come in the next build.')),
            ),
          ),
        ],
      ),
      bottomNavigationBar: inv.balance > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _recordPayment(inv),
                        icon: const Icon(Icons.payments_outlined),
                        label: Text('Record payment of ${money(inv.balance)}'),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: CenteredListView(
        maxWidth: 820,
        children: [
          // Business-only status line (not printed on the invoice).
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                StatusChip(status),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    inv.balance > 0 ? '${money(inv.balance)} due' : 'Fully paid',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, PageRoutes.invoiceTemplate),
                  icon: const Icon(Icons.palette_outlined, size: 18),
                  label: const Text('Customize design'),
                ),
              ],
            ),
          ),
          InvoiceDocument(
            invoice: inv,
            customer: customer,
            profile: settingState.profile,
            template: settingState.template,
          ),
          const SizedBox(height: 8),

          if (source != null) ...[
            const SectionHeader('Created from transaction'),
            Card(clipBehavior: Clip.antiAlias, child: TransactionTile(transaction: source)),
            if (source.amount > inv.total + 0.004)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  '${money(source.amount - inv.total)} of this transaction is unapplied.',
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),
          ],

          if (estimate != null || schedule != null) ...[
            const SectionHeader('Where it came from'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  if (estimate != null)
                    ListTile(
                      leading: IconBadge(Icons.request_quote_outlined, color: scheme.primary),
                      title: Text('Converted from ${estimate.number}'),
                      subtitle: Text('Estimate dated ${fmtDate(estimate.issueDate)}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => openEstimateDetail(context, estimate.id),
                    ),
                  if (schedule != null)
                    ListTile(
                      leading: IconBadge(Icons.autorenew_rounded, color: scheme.primary),
                      title: const Text('Issued by a recurring schedule'),
                      subtitle: Text(schedule.rhythm),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => openRecurringDetail(context, schedule.id),
                    ),
                ],
              ),
            ),
          ],

          if (payments.isNotEmpty) ...[
            const SectionHeader('Payments'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                  children: [for (final p in payments) TransactionTile(transaction: p)]),
            ),
          ],
        ],
      ),
    ),
    );
  }
}
