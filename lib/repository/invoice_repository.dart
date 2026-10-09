import 'dart:math' as math;

import '../databases/local_db.dart';
import '../exception/app_exception.dart';
import '../models/account_model.dart';
import '../models/invoice_model.dart';
import '../models/transaction_model.dart';
import '../utils/format.dart';

/// Invoices, and the two operations that also touch transactions:
/// creating an invoice from a transaction, and recording a payment.
class InvoiceRepository {
  InvoiceRepository(this._db);

  final LocalDb _db;

  Stream<void> get changes => _db.changes.where((t) => t == DbTable.invoices);

  /// Newest first.
  Future<List<Invoice>> fetchInvoices() async =>
      _db.invoices.values.toList()..sort((a, b) => b.issueDate.compareTo(a.issueDate));

  /// The next free INV-#### number (skips numbers typed in by hand).
  Future<String> nextInvoiceNumber() async => _nextFreeNumber();

  String _nextFreeNumber() {
    var n = _db.invoiceCounter;
    String fmt(int n) => 'INV-${n.toString().padLeft(4, '0')}';
    while (_numberTaken(fmt(n))) {
      n++;
    }
    return fmt(n);
  }

  bool _numberTaken(String number) =>
      _db.invoices.values.any((i) => i.number.toLowerCase() == number.toLowerCase());

  /// Creates an invoice. When [sourceTransactionId] is given, the invoice is
  /// linked to that transaction and its amount is applied as a payment
  /// (capped at the invoice total; any excess stays unapplied).
  ///
  /// [estimateId] marks that estimate as converted, in the same write.
  /// [recurringId] records which schedule issued it (set by
  /// RecurringRepository only). Pass a null [number] to use the next free one.
  Future<Invoice> createInvoice({
    required String customerId,
    String? number,
    required DateTime issueDate,
    required DateTime dueDate,
    required List<InvoiceLine> lines,
    String notes = '',
    String? sourceTransactionId,
    String? estimateId,
    String? recurringId,
  }) async {
    final trimmed = (number ?? _nextFreeNumber()).trim();
    if (trimmed.isEmpty) throw const AppException('Invoice number is required.');
    if (lines.isEmpty) throw const AppException('Add at least one item.');
    if (!_db.customers.containsKey(customerId)) {
      throw const AppException('Choose a customer.');
    }
    if (_numberTaken(trimmed)) {
      throw AppException('Invoice number $trimmed already exists.');
    }
    if (dateOnly(dueDate).isBefore(dateOnly(issueDate))) {
      throw const AppException('The due date can\'t be before the invoice date.');
    }

    final estimate = estimateId == null ? null : _db.estimates[estimateId];
    if (estimateId != null) {
      if (estimate == null) throw const AppException('Estimate not found.');
      if (estimate.isConverted) {
        throw const AppException('This estimate has already been invoiced.');
      }
    }

    final BankTransaction? source =
        sourceTransactionId == null ? null : _db.transactions[sourceTransactionId];
    // Only money categorised as income is a sale (not a loan, owner money…).
    final sourceIsIncome = source != null &&
        _db.chart.values.any((a) =>
            a.type == AccountType.income &&
            a.name.toLowerCase() == source.category.trim().toLowerCase());
    if (sourceTransactionId != null &&
        (source == null || !source.isInvoiceable || !sourceIsIncome)) {
      throw const AppException('This transaction can no longer be invoiced '
          '(already linked, not income, or not a sale).');
    }

    return _db.transaction({
      DbTable.invoices,
      DbTable.transactions,
      if (estimate != null) DbTable.estimates,
    }, () {
      var inv = Invoice(
        id: _db.newId('i'),
        number: trimmed,
        customerId: customerId,
        issueDate: dateOnly(issueDate),
        dueDate: dateOnly(dueDate),
        lines: List.unmodifiable(lines),
        notes: notes.trim(),
        sourceTransactionId: source?.id,
        estimateId: estimate?.id,
        recurringId: recurringId,
      );
      if (source != null) {
        inv = inv.copyWith(amountPaid: round2(math.min(source.amount, inv.total)));
        _db.transactions[source.id] =
            source.linkTo(invoiceId: inv.id, customerId: customerId);
      }
      if (estimate != null) {
        _db.estimates[estimate.id] = estimate.copyWith(invoiceId: inv.id);
      }
      _db.invoices[inv.id] = inv;
      _db.invoiceCounter++;
      return inv;
    });
  }

  /// Records a customer payment against an invoice (creates an income txn).
  Future<void> recordPayment({
    required String invoiceId,
    required double amount,
    required DateTime date,
    required String account,
  }) async {
    final inv = _db.invoices[invoiceId];
    if (inv == null) throw const AppException('Invoice not found.');
    final applied = round2(math.min(amount, inv.balance));
    if (applied <= 0) throw const AppException('Nothing left to pay on this invoice.');

    _db.transaction({DbTable.invoices, DbTable.transactions}, () {
      final t = BankTransaction(
        id: _db.newId('t'),
        date: dateOnly(date),
        description: 'Payment for ${inv.number}',
        amount: applied,
        type: TransactionType.income,
        account: account,
        category: 'Sales',
        customerId: inv.customerId,
        invoiceId: inv.id,
      );
      _db.transactions[t.id] = t;
      _db.invoices[inv.id] = inv.copyWith(amountPaid: round2(inv.amountPaid + applied));
    });
  }
}
