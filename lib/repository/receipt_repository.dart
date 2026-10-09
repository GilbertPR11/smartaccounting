import 'dart:typed_data';

import '../config/constants.dart';
import '../databases/local_db.dart';
import '../exception/app_exception.dart';
import '../models/receipt_model.dart';
import '../models/transaction_model.dart';
import '../utils/format.dart';

/// Receipt photos: captured first, filled in later, then either recorded as
/// an expense or attached to a bill (see BillRepository.createBill).
class ReceiptRepository {
  ReceiptRepository(this._db);

  final LocalDb _db;

  Stream<void> get changes => _db.changes.where((t) => t == DbTable.receipts);

  /// To-review first, then newest.
  Future<List<Receipt>> fetchReceipts() async => _db.receipts.values.toList()
    ..sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      return b.addedOn.compareTo(a.addedOn);
    });

  /// Saves a new photo into "To review".
  Future<Receipt> addReceipt(Uint8List imageBytes) async {
    if (imageBytes.isEmpty) throw const AppException('That image is empty.');
    if (imageBytes.length > Constants.maxReceiptBytes) {
      throw const AppException('That image is too large. Please choose one under 4 MB.');
    }
    return _db.transaction({DbTable.receipts}, () {
      final r = Receipt(id: _db.newId('r'), imageBytes: imageBytes, addedOn: _db.today);
      _db.receipts[r.id] = r;
      return r;
    });
  }

  /// Saves details without recording anything ("fill in later").
  Future<void> updateDetails(Receipt receipt) async {
    final existing = _db.receipts[receipt.id];
    if (existing == null) throw const AppException('Receipt not found.');
    if (existing.isDone) throw const AppException('This receipt is already recorded.');
    _db.transaction({DbTable.receipts}, () => _db.receipts[receipt.id] = receipt);
  }

  /// Records the receipt as money already spent: creates the expense.
  Future<void> recordAsExpense(Receipt receipt) async {
    final existing = _db.receipts[receipt.id];
    if (existing == null) throw const AppException('Receipt not found.');
    if (existing.isDone) throw const AppException('This receipt is already recorded.');
    final amount = receipt.amount;
    if (amount == null || amount <= 0) throw const AppException('Enter the amount paid.');
    if (receipt.date == null) throw const AppException('Enter the date on the receipt.');
    if (receipt.category == null) throw const AppException('Choose a category.');
    if (receipt.account == null) throw const AppException('Choose which account paid.');
    final vendorName = receipt.vendorId != null
        ? _db.vendors[receipt.vendorId]?.name
        : (receipt.merchant.trim().isEmpty ? null : receipt.merchant.trim());

    _db.transaction({DbTable.receipts, DbTable.transactions}, () {
      final t = BankTransaction(
        id: _db.newId('t'),
        date: dateOnly(receipt.date!),
        description: vendorName ?? receipt.category!,
        amount: round2(amount),
        type: TransactionType.expense,
        account: receipt.account!,
        category: receipt.category!,
        receiptId: receipt.id,
      );
      _db.transactions[t.id] = t;
      _db.receipts[receipt.id] =
          receipt.copyWith(status: ReceiptStatus.recorded, transactionId: t.id);
    });
  }

  /// Deletes a receipt that hasn't been recorded yet.
  Future<void> deleteReceipt(String id) async {
    final existing = _db.receipts[id];
    if (existing == null) return;
    if (existing.isDone) {
      throw const AppException('Recorded receipts are kept as proof and can\'t be deleted.');
    }
    _db.transaction({DbTable.receipts}, () => _db.receipts.remove(id));
  }
}
