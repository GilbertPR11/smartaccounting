import 'dart:math' as math;

import '../databases/local_db.dart';
import '../exception/app_exception.dart';
import '../models/bill_model.dart';
import '../models/receipt_model.dart';
import '../models/transaction_model.dart';
import '../utils/format.dart';

/// Bills, and paying them (which creates a money-out transaction).
class BillRepository {
  BillRepository(this._db);

  final LocalDb _db;

  Stream<void> get changes => _db.changes.where((t) => t == DbTable.bills);

  /// Soonest due first, so what needs paying is at the top.
  Future<List<Bill>> fetchBills() async =>
      _db.bills.values.toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  Future<Bill> createBill({
    required String vendorId,
    required String number,
    required DateTime issueDate,
    required DateTime dueDate,
    required List<BillLine> lines,
    String notes = '',
    String? receiptId,
  }) async {
    if (!_db.vendors.containsKey(vendorId)) throw const AppException('Choose a vendor.');
    if (lines.isEmpty) throw const AppException('Add at least one line.');
    if (lines.any((l) => l.amount <= 0)) {
      throw const AppException('Every line needs an amount above zero.');
    }
    if (dateOnly(dueDate).isBefore(dateOnly(issueDate))) {
      throw const AppException('The due date cannot be before the bill date.');
    }
    final ref = number.trim();
    if (ref.isNotEmpty &&
        _db.bills.values.any(
            (b) => b.vendorId == vendorId && b.number.toLowerCase() == ref.toLowerCase())) {
      throw AppException('You already entered bill $ref from this vendor.');
    }
    final receipt = receiptId == null ? null : _db.receipts[receiptId];
    if (receiptId != null && (receipt == null || receipt.isDone)) {
      throw const AppException('That receipt is already recorded.');
    }

    return _db.transaction({DbTable.bills, DbTable.receipts}, () {
      final bill = Bill(
        id: _db.newId('b'),
        vendorId: vendorId,
        number: ref,
        issueDate: dateOnly(issueDate),
        dueDate: dateOnly(dueDate),
        lines: List.unmodifiable(lines),
        notes: notes.trim(),
      );
      _db.bills[bill.id] = bill;
      if (receipt != null) {
        _db.receipts[receipt.id] =
            receipt.copyWith(status: ReceiptStatus.attached, billId: bill.id, vendorId: vendorId);
      }
      return bill;
    });
  }

  /// Pays (part of) a bill from [account]. Creates a money-out transaction.
  Future<void> recordPayment({
    required String billId,
    required double amount,
    required DateTime date,
    required String account,
  }) async {
    final bill = _db.bills[billId];
    if (bill == null) throw const AppException('Bill not found.');
    final applied = round2(math.min(amount, bill.balance));
    if (applied <= 0) throw const AppException('This bill is already paid.');

    _db.transaction({DbTable.bills, DbTable.transactions}, () {
      final vendor = _db.vendors[bill.vendorId];
      final t = BankTransaction(
        id: _db.newId('t'),
        date: dateOnly(date),
        description: bill.number.isEmpty
            ? 'Payment to ${vendor?.name ?? 'vendor'}'
            : 'Payment for ${bill.number}',
        amount: applied,
        type: TransactionType.expense,
        account: account,
        category: bill.mainCategory,
        billId: bill.id,
      );
      _db.transactions[t.id] = t;
      _db.bills[bill.id] = bill.copyWith(amountPaid: round2(bill.amountPaid + applied));
    });
  }
}
