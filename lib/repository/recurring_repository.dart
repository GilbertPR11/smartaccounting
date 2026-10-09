import '../databases/local_db.dart';
import '../exception/app_exception.dart';
import '../models/invoice_model.dart';
import '../models/recurring_invoice_model.dart';
import '../utils/format.dart';
import 'invoice_repository.dart';

/// Recurring invoice schedules, and issuing the invoices they owe.
///
/// There is no server, so nothing runs at midnight. Instead [issueDue] runs
/// when the app starts and whenever a schedule is saved or resumed, and
/// catches up on every date that has passed (each invoice keeps its own
/// scheduled date). Invoices are created through [InvoiceRepository] so they
/// follow exactly the same rules as hand-made ones.
class RecurringRepository {
  RecurringRepository(this._db, this._invoices);

  final LocalDb _db;
  final InvoiceRepository _invoices;

  /// Safety cap per schedule per run, e.g. a weekly schedule back-dated
  /// two years. The rest are issued on the next run.
  static const int maxCatchUp = 24;

  Stream<void> get changes => _db.changes.where((t) => t == DbTable.recurring);

  /// Active first, then by next date.
  Future<List<RecurringInvoice>> fetchSchedules() async {
    final list = _db.recurring.values.toList();
    int rank(RecurringInvoice r) => r.status.index;
    list.sort((a, b) {
      final byStatus = rank(a).compareTo(rank(b));
      if (byStatus != 0) return byStatus;
      final an = a.nextDate, bn = b.nextDate;
      if (an == null || bn == null) return 0;
      return an.compareTo(bn);
    });
    return list;
  }

  void _validate({
    required String customerId,
    required List<InvoiceLine> lines,
    required DateTime startDate,
    DateTime? endDate,
    int? maxCount,
    required int termsDays,
  }) {
    if (!_db.customers.containsKey(customerId)) {
      throw const AppException('Choose a customer.');
    }
    if (lines.isEmpty) throw const AppException('Add at least one item.');
    if (endDate != null && dateOnly(endDate).isBefore(dateOnly(startDate))) {
      throw const AppException('The end date can\'t be before the first invoice date.');
    }
    if (maxCount != null && maxCount < 1) {
      throw const AppException('Issue at least one invoice.');
    }
    if (termsDays < 0) throw const AppException('Payment terms can\'t be negative.');
  }

  /// Saves a new schedule, then issues any invoice already due (a schedule
  /// starting today issues its first invoice straight away).
  Future<RecurringInvoice> createSchedule({
    required String customerId,
    required List<InvoiceLine> lines,
    required RecurFrequency frequency,
    required DateTime startDate,
    DateTime? endDate,
    int? maxCount,
    int termsDays = 14,
    String notes = '',
  }) async {
    _validate(
        customerId: customerId,
        lines: lines,
        startDate: startDate,
        endDate: endDate,
        maxCount: maxCount,
        termsDays: termsDays);
    final r = _db.transaction({DbTable.recurring}, () {
      final r = RecurringInvoice(
        id: _db.newId('r'),
        customerId: customerId,
        lines: List.unmodifiable(lines),
        frequency: frequency,
        startDate: dateOnly(startDate),
        endDate: endDate == null ? null : dateOnly(endDate),
        maxCount: maxCount,
        termsDays: termsDays,
        notes: notes.trim(),
      );
      _db.recurring[r.id] = r;
      return r;
    });
    await issueDue();
    return _db.recurring[r.id]!;
  }

  /// Changes what future invoices will contain. Invoices already issued are
  /// not touched. The rhythm (frequency, start) can only change before the
  /// first invoice, otherwise the dates already issued would stop lining up.
  Future<RecurringInvoice> updateSchedule({
    required String id,
    required String customerId,
    required List<InvoiceLine> lines,
    required RecurFrequency frequency,
    required DateTime startDate,
    DateTime? endDate,
    int? maxCount,
    int termsDays = 14,
    String notes = '',
  }) async {
    final current = _db.recurring[id];
    if (current == null) throw const AppException('Schedule not found.');
    _validate(
        customerId: customerId,
        lines: lines,
        startDate: startDate,
        endDate: endDate,
        maxCount: maxCount,
        termsDays: termsDays);
    final started = current.issuedCount > 0;
    if (started &&
        (frequency != current.frequency ||
            dateOnly(startDate) != dateOnly(current.startDate))) {
      throw const AppException(
          'This schedule has already issued invoices, so its start date and '
          'frequency are fixed. Create a new schedule instead.');
    }
    if (maxCount != null && maxCount < current.issuedCount) {
      throw AppException('It has already issued ${current.issuedCount} invoices.');
    }
    _db.transaction({DbTable.recurring}, () {
      _db.recurring[id] = current.copyWith(
        customerId: customerId,
        lines: List.unmodifiable(lines),
        frequency: frequency,
        startDate: dateOnly(startDate),
        endDate: endDate == null ? null : dateOnly(endDate),
        clearEndDate: endDate == null,
        maxCount: maxCount,
        clearMaxCount: maxCount == null,
        termsDays: termsDays,
        notes: notes.trim(),
      );
    });
    await issueDue();
    return _db.recurring[id]!;
  }

  /// Pausing stops new invoices. Resuming does NOT back-fill the dates
  /// skipped while paused: those are skipped for good.
  Future<void> setPaused(String id, bool paused) async {
    final current = _db.recurring[id];
    if (current == null) throw const AppException('Schedule not found.');
    if (current.paused == paused) return;
    var updated = current.copyWith(paused: paused);
    if (!paused) {
      var n = updated.issuedCount;
      final today = _db.today;
      while (!updated.copyWith(issuedCount: n).isFinished &&
          updated.occurrence(n).isBefore(today)) {
        n++;
      }
      updated = updated.copyWith(issuedCount: n);
    }
    _db.transaction({DbTable.recurring}, () => _db.recurring[id] = updated);
    if (!paused) await issueDue();
  }

  /// Deletes the schedule. Invoices it already issued stay.
  Future<void> deleteSchedule(String id) async {
    if (!_db.recurring.containsKey(id)) throw const AppException('Schedule not found.');
    _db.transaction({DbTable.recurring}, () => _db.recurring.remove(id));
  }

  /// Issues every invoice whose date has come, for every active schedule.
  /// Returns the invoices created (oldest first).
  Future<List<Invoice>> issueDue() async {
    final today = _db.today;
    final created = <Invoice>[];
    for (final id in _db.recurring.keys.toList()) {
      var r = _db.recurring[id]!;
      var issued = 0;
      while (!r.paused && issued < maxCatchUp) {
        final date = r.nextDate;
        if (date == null || date.isAfter(today)) break;
        final inv = await _invoices.createInvoice(
          customerId: r.customerId,
          issueDate: date,
          dueDate: date.add(Duration(days: r.termsDays)),
          lines: r.lines,
          notes: r.notes,
          recurringId: r.id,
        );
        created.add(inv);
        r = r.copyWith(issuedCount: r.issuedCount + 1);
        final next = r;
        _db.transaction({DbTable.recurring}, () => _db.recurring[id] = next);
        issued++;
      }
    }
    return created;
  }
}
