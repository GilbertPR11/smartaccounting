import '../databases/local_db.dart';
import '../exception/app_exception.dart';
import '../models/reconciliation_model.dart';
import '../models/transaction_model.dart';
import '../utils/format.dart';

/// Bank reconciliation: ticking transactions off against a bank statement
/// until the app's balance matches the bank's.
///
/// Each reconciliation starts from the previous one's ending balance (or,
/// for the first one, the account's opening balance). Reconciled
/// transactions are locked: TransactionRepository won't change their date,
/// amount or account, or delete them, until the reconciliation is undone.
class ReconciliationRepository {
  ReconciliationRepository(this._db);

  final LocalDb _db;

  Stream<void> get changes => _db.changes.where((t) => t == DbTable.reconciliations);

  /// Newest statement first.
  Future<List<Reconciliation>> fetchReconciliations() async =>
      _db.reconciliations.values.toList()
        ..sort((a, b) => b.statementDate.compareTo(a.statementDate));

  Reconciliation? _last(String account) {
    Reconciliation? last;
    for (final r in _db.reconciliations.values) {
      if (r.account != account) continue;
      if (last == null || r.statementDate.isAfter(last.statementDate)) last = r;
    }
    return last;
  }

  /// Where the next reconciliation of [account] starts.
  double beginningBalance(String account) {
    final last = _last(account);
    if (last != null) return last.endingBalance;
    final opening = _db.chart[_db.openingAccountId]?.name;
    return opening == account ? _db.openingBalance : 0;
  }

  /// The day after the last reconciled statement, if any.
  DateTime? lastStatementDate(String account) => _last(account)?.statementDate;

  Future<Reconciliation> complete({
    required String account,
    required DateTime statementDate,
    required double endingBalance,
    required List<String> transactionIds,
  }) async {
    if (!_db.accounts.contains(account)) throw const AppException('Choose a bank or cash account.');
    final date = dateOnly(statementDate);
    final last = lastStatementDate(account);
    if (last != null && !date.isAfter(last)) {
      throw AppException('This account is already reconciled to ${fmtDate(last)}. '
          'Choose a later statement date.');
    }
    final picked = <BankTransaction>[];
    for (final id in transactionIds.toSet()) {
      final t = _db.transactions[id];
      if (t == null || t.account != account) {
        throw const AppException('A ticked transaction isn\'t in this account.');
      }
      if (t.reconciled) throw const AppException('A ticked transaction is already reconciled.');
      if (dateOnly(t.date).isAfter(date)) {
        throw const AppException('Only transactions up to the statement date can be ticked.');
      }
      picked.add(t);
    }
    final cleared = round2(beginningBalance(account) +
        picked.fold<double>(0, (s, t) => s + (t.isIncome ? t.amount : -t.amount)));
    final difference = round2(endingBalance - cleared);
    if (difference.abs() > 0.004) {
      throw AppException('Still ${money(difference.abs())} out. Tick or untick transactions, '
          'or add the missing ones (bank fees, interest), until the difference is zero.');
    }

    return _db.transaction({DbTable.reconciliations, DbTable.transactions}, () {
      for (final t in picked) {
        _db.transactions[t.id] = t.copyWith(reconciled: true);
      }
      final r = Reconciliation(
        id: _db.newId('k'),
        account: account,
        statementDate: date,
        endingBalance: round2(endingBalance),
        transactionIds: List.unmodifiable(picked.map((t) => t.id)),
        completedOn: _db.today,
      );
      _db.reconciliations[r.id] = r;
      return r;
    });
  }

  /// Undoes the latest reconciliation of an account (only the latest, so
  /// the chain of beginning balances stays correct).
  Future<void> undo(String reconciliationId) async {
    final r = _db.reconciliations[reconciliationId];
    if (r == null) throw const AppException('Reconciliation not found.');
    if (_last(r.account)?.id != r.id) {
      throw const AppException('Only the latest reconciliation of an account can be undone.');
    }
    _db.transaction({DbTable.reconciliations, DbTable.transactions}, () {
      for (final id in r.transactionIds) {
        final t = _db.transactions[id];
        if (t != null) _db.transactions[id] = t.copyWith(reconciled: false);
      }
      _db.reconciliations.remove(r.id);
    });
  }
}
