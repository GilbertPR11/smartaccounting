import '../databases/local_db.dart';
import '../exception/app_exception.dart';
import '../models/journal_model.dart';
import '../utils/format.dart';

/// Manual journal entries: adjustments that don't come from an invoice, bill
/// or bank transaction (depreciation, corrections, owner's non-cash
/// contributions…). Everything else in the ledger is derived.
class JournalRepository {
  JournalRepository(this._db);

  final LocalDb _db;

  Stream<void> get changes => _db.changes.where((t) => t == DbTable.journals);

  /// Newest first.
  Future<List<JournalEntry>> fetchJournals() async =>
      _db.journals.values.toList()..sort((a, b) => b.date.compareTo(a.date));

  List<JournalLine> _validate(String description, List<JournalLine> lines) {
    if (description.trim().isEmpty) throw const AppException('Add a description.');
    if (lines.any((l) => l.debit < 0 || l.credit < 0)) {
      throw const AppException('Amounts can\'t be negative.');
    }
    final kept = [
      for (final l in lines)
        if (l.debit > 0.004 || l.credit > 0.004)
          JournalLine(
              accountId: l.accountId,
              debit: round2(l.debit),
              credit: round2(l.credit),
              memo: l.memo.trim()),
    ];
    if (kept.length < 2) throw const AppException('A journal entry needs at least two lines.');
    for (final l in kept) {
      if (l.debit > 0 && l.credit > 0) {
        throw const AppException('Each line is either a debit or a credit, not both.');
      }
      if (l.debit < 0 || l.credit < 0) throw const AppException('Amounts can\'t be negative.');
      if (!_db.chart.containsKey(l.accountId)) {
        throw const AppException('Choose an account on every line.');
      }
    }
    final entry = JournalEntry(id: '', date: _db.today, description: '', lines: kept);
    if (!entry.isBalanced) {
      throw AppException('Debits (${money(entry.totalDebit)}) and credits '
          '(${money(entry.totalCredit)}) must be equal.');
    }
    return kept;
  }

  Future<JournalEntry> createJournal({
    required DateTime date,
    required String description,
    required List<JournalLine> lines,
  }) async {
    final kept = _validate(description, lines);
    return _db.transaction({DbTable.journals}, () {
      final j = JournalEntry(
        id: _db.newId('j'),
        date: dateOnly(date),
        description: description.trim(),
        lines: List.unmodifiable(kept),
      );
      _db.journals[j.id] = j;
      return j;
    });
  }

  Future<JournalEntry> updateJournal({
    required String id,
    required DateTime date,
    required String description,
    required List<JournalLine> lines,
  }) async {
    if (!_db.journals.containsKey(id)) throw const AppException('Journal entry not found.');
    final kept = _validate(description, lines);
    return _db.transaction({DbTable.journals}, () {
      final j = JournalEntry(
        id: id,
        date: dateOnly(date),
        description: description.trim(),
        lines: List.unmodifiable(kept),
      );
      _db.journals[id] = j;
      return j;
    });
  }

  Future<void> deleteJournal(String id) async {
    if (!_db.journals.containsKey(id)) throw const AppException('Journal entry not found.');
    _db.transaction({DbTable.journals}, () => _db.journals.remove(id));
  }
}
