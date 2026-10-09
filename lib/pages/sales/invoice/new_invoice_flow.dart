import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/transaction/transaction_bloc.dart';
import '../../../models/invoice_model.dart';
import '../../../models/transaction_model.dart';
import '../../../routes/routes.dart';
import '../estimate/estimate_flows.dart';
import '../recurring/recurring_flows.dart';

/// Navigation flows for invoices, shared by every "New invoice" button.
/// All navigation goes through named routes in routes/routes.dart.

/// "New…" sheet: invoice from a payment, blank invoice, estimate, recurring.
Future<void> showNewInvoiceSheet(BuildContext context) async {
  final count = context.read<TransactionBloc>().state.invoiceable.length;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('From a transaction'),
            subtitle: Text(count == 0
                ? 'No uninvoiced payments right now'
                : '$count payments received without an invoice'),
            enabled: count > 0,
            onTap: () => Navigator.pop(ctx, 'txn'),
          ),
          ListTile(
            leading: const Icon(Icons.note_add_outlined),
            title: const Text('Blank invoice'),
            subtitle: const Text('Bill a customer for work not yet paid'),
            onTap: () => Navigator.pop(ctx, 'blank'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.request_quote_outlined),
            title: const Text('Estimate'),
            subtitle: const Text('Quote a price first; invoice it once accepted'),
            onTap: () => Navigator.pop(ctx, 'estimate'),
          ),
          ListTile(
            leading: const Icon(Icons.autorenew_rounded),
            title: const Text('Recurring invoice'),
            subtitle: const Text('Bill the same thing every week, month or year'),
            onTap: () => Navigator.pop(ctx, 'recurring'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'txn':
      await openTransactionPicker(context);
    case 'blank':
      await openInvoiceForm(context);
    case 'estimate':
      await openEstimateForm(context);
    case 'recurring':
      await openRecurringForm(context);
  }
}

Future<void> openTransactionPicker(BuildContext context) =>
    Navigator.pushNamed(context, PageRoutes.transactionPicker);

Future<void> openInvoiceDetail(BuildContext context, String invoiceId) =>
    Navigator.pushNamed(context, PageRoutes.invoiceDetail,
        arguments: InvoiceDetailArgs(invoiceId));

/// Opens the invoice form; on save, shows the created invoice.
/// [replace] swaps out the current page (used from the transaction picker).
Future<void> openInvoiceForm(
  BuildContext context, {
  BankTransaction? source,
  bool replace = false,
}) async {
  final invoice = await Navigator.pushNamed<Invoice>(
    context,
    PageRoutes.invoiceForm,
    arguments: InvoiceFormArgs(source: source),
  );
  if (invoice == null || !context.mounted) return;
  final args = InvoiceDetailArgs(invoice.id, justCreated: true);
  if (replace) {
    Navigator.pushReplacementNamed(context, PageRoutes.invoiceDetail, arguments: args);
  } else {
    Navigator.pushNamed(context, PageRoutes.invoiceDetail, arguments: args);
  }
}
