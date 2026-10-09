import 'package:flutter_test/flutter_test.dart';
import 'package:smartaccounting/bloc/invoice/invoice_bloc.dart';
import 'package:smartaccounting/bloc/transaction/transaction_bloc.dart';
import 'package:smartaccounting/config/constants.dart';
import 'package:smartaccounting/databases/local_db.dart';
import 'package:smartaccounting/exception/app_exception.dart';
import 'package:smartaccounting/models/invoice_model.dart';
import 'package:smartaccounting/models/transaction_model.dart';
import 'package:smartaccounting/repository/invoice_repository.dart';
import 'package:smartaccounting/repository/transaction_repository.dart';

void main() {
  final today = DateTime(2026, 10, 7);
  late LocalDb db;
  late InvoiceRepository invoices;
  late TransactionRepository transactions;

  setUp(() {
    db = LocalDb(today: today);
    invoices = InvoiceRepository(db);
    transactions = TransactionRepository(db);
  });

  /// Lets Bloc events and stream deliveries run.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<List<BankTransaction>> invoiceable() async =>
      (await transactions.fetchTransactions()).where((t) => t.isInvoiceable).toList();

  test('only real, uninvoiced sales are invoiceable', () async {
    final list = await invoiceable();
    expect(list, isNotEmpty);
    expect(list.every((t) => t.isIncome && t.invoiceId == null), isTrue);
    expect(list.any((t) => t.category == 'Owner Investment'), isFalse);
  });

  test('creating from a txn links it and marks the invoice paid', () async {
    final txn = (await invoiceable()).firstWhere((t) => t.amount == 1296);
    final inv = await invoices.createInvoice(
      customerId: txn.customerId!,
      number: await invoices.nextInvoiceNumber(),
      issueDate: txn.date,
      dueDate: txn.date,
      lines: [
        InvoiceLine(description: 'Bookkeeping', unitPrice: 1200, tax: Constants.taxes.first),
      ],
      sourceTransactionId: txn.id,
    );
    expect(inv.total, 1296);
    expect(inv.amountPaid, 1296);
    expect(inv.statusOn(today), InvoiceStatus.paid);
    expect(db.transactions[txn.id]!.invoiceId, inv.id);
    expect((await invoiceable()).any((t) => t.id == txn.id), isFalse);
  });

  test('the same txn cannot be invoiced twice', () async {
    final txn = (await invoiceable()).first;
    final customerId = db.customers.keys.first;
    InvoiceLine line() => InvoiceLine(description: 'x', unitPrice: txn.amount);
    await invoices.createInvoice(
        customerId: customerId, number: 'A-1', issueDate: txn.date,
        dueDate: txn.date, lines: [line()], sourceTransactionId: txn.id);
    expect(
      () => invoices.createInvoice(
          customerId: customerId, number: 'A-2', issueDate: txn.date,
          dueDate: txn.date, lines: [line()], sourceTransactionId: txn.id),
      throwsA(isA<AppException>()),
    );
  });

  test('invoice larger than the txn is partially paid', () async {
    final txn = (await invoiceable()).firstWhere((t) => t.amount == 350);
    final inv = await invoices.createInvoice(
        customerId: db.customers.keys.first, number: 'B-1', issueDate: today,
        dueDate: today.add(const Duration(days: 7)),
        lines: const [InvoiceLine(description: 'Job', unitPrice: 500)],
        sourceTransactionId: txn.id);
    expect(inv.amountPaid, 350);
    expect(inv.balance, 150);
    expect(inv.statusOn(today), InvoiceStatus.partial);
  });

  test('blocs reload by themselves after a write', () async {
    final invoiceBloc = InvoiceBloc(repository: invoices)..add(const LoadInvoices());
    final txnBloc = TransactionBloc(repository: transactions)..add(const LoadTransactions());
    await settle();
    final before = invoiceBloc.state.invoices.length;
    final txn = txnBloc.state.invoiceable.first;

    await invoices.createInvoice(
        customerId: db.customers.keys.first, number: 'C-1', issueDate: today,
        dueDate: today, lines: [InvoiceLine(description: 'x', unitPrice: txn.amount)],
        sourceTransactionId: txn.id);
    await settle();

    expect(invoiceBloc.state.invoices.length, before + 1);
    expect(txnBloc.state.invoiceable.any((t) => t.id == txn.id), isFalse);
    await invoiceBloc.close();
    await txnBloc.close();
  });
}
