import '../databases/local_db.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  TransactionRepository(this._db);

  final LocalDb _db;

  Stream<void> get changes => _db.changes.where((t) => t == DbTable.transactions);

  /// Newest first.
  Future<List<BankTransaction>> fetchTransactions() async =>
      _db.transactions.values.toList()..sort((a, b) => b.date.compareTo(a.date));
}
