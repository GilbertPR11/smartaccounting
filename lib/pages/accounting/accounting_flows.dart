import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/journal/journal_bloc.dart';
import '../../bloc/transaction/transaction_bloc.dart';
import '../../models/journal_model.dart';
import '../../models/transaction_model.dart';
import '../../routes/routes.dart';
import '../purchases/purchase_flows.dart';
import '../sales/invoice/new_invoice_flow.dart';

// Navigation flows for the Accounting area.

/// Add (or edit) a bank/cash transaction. Shows a confirmation on save.
Future<void> openTransactionForm(
  BuildContext context, {
  BankTransaction? transaction,
  TransactionType type = TransactionType.expense,
}) async {
  final saved = await Navigator.pushNamed<BankTransaction>(
    context,
    PageRoutes.transactionForm,
    arguments: TransactionFormArgs(transaction: transaction, type: type),
  );
  if (saved == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(transaction == null ? 'Transaction added' : 'Transaction saved')));
}

/// Add (or edit) a manual journal entry.
Future<void> openJournalForm(BuildContext context, {JournalEntry? entry}) async {
  final saved = await Navigator.pushNamed<JournalEntry>(
    context,
    PageRoutes.journalForm,
    arguments: JournalFormArgs(entry: entry),
  );
  if (saved == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(entry == null ? 'Journal entry added' : 'Journal entry saved')));
}

/// Opens whatever a ledger entry came from: the invoice, bill, transaction
/// or journal entry. The opening balance has nothing to open.
Future<void> openEntrySource(BuildContext context, JournalEntry entry) async {
  final id = entry.sourceId;
  switch (entry.source) {
    case JournalSource.invoice:
      if (id != null) await openInvoiceDetail(context, id);
    case JournalSource.bill:
      if (id != null) await openBillDetail(context, id);
    case JournalSource.invoicePayment:
    case JournalSource.billPayment:
    case JournalSource.transaction:
      final t = context.read<TransactionBloc>().state.byId(id);
      if (t != null) await openTransactionForm(context, transaction: t);
    case JournalSource.manual:
      final j = context.read<JournalBloc>().state.byId(entry.id);
      if (j != null) await openJournalForm(context, entry: j);
    case JournalSource.opening:
      break;
  }
}
