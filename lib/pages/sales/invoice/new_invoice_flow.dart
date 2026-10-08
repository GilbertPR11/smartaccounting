import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/transaction/transaction_bloc.dart';
import '../../../models/invoice_model.dart';
import '../../../models/transaction_model.dart';
import '../../../routes/routes.dart';

/// Navigation flows for invoices, shared by every "New invoice" button.
/// All navigation goes through named routes in routes/routes.dart.

Future<void> showNewInvoiceSheet(BuildContext context) async {
  final count = context.read<TransactionBloc>().state.invoiceable.length;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (choice == 'txn') await openTransactionPicker(context);
  if (choice == 'blank') await openInvoiceForm(context);
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
