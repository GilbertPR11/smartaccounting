import '../databases/local_db.dart';
import '../exception/app_exception.dart';
import '../models/estimate_model.dart';
import '../models/invoice_model.dart';
import '../utils/format.dart';

/// Estimates (quotes). They never create transactions or receivables.
/// Converting one to an invoice goes through InvoiceRepository.createInvoice
/// with `estimateId`, so the invoice and the "converted" mark land together.
class EstimateRepository {
  EstimateRepository(this._db);

  final LocalDb _db;

  Stream<void> get changes => _db.changes.where((t) => t == DbTable.estimates);

  /// Newest first.
  Future<List<Estimate>> fetchEstimates() async =>
      _db.estimates.values.toList()..sort((a, b) => b.issueDate.compareTo(a.issueDate));

  /// The next free EST-#### number.
  Future<String> nextEstimateNumber() async {
    var n = _db.estimateCounter;
    String fmt(int n) => 'EST-${n.toString().padLeft(4, '0')}';
    while (_numberTaken(fmt(n))) {
      n++;
    }
    return fmt(n);
  }

  bool _numberTaken(String number, {String? exceptId}) => _db.estimates.values.any(
      (e) => e.id != exceptId && e.number.toLowerCase() == number.trim().toLowerCase());

  void _validate({
    required String number,
    required String customerId,
    required DateTime issueDate,
    required DateTime expiryDate,
    required List<InvoiceLine> lines,
    String? exceptId,
  }) {
    if (number.trim().isEmpty) throw const AppException('Estimate number is required.');
    if (!_db.customers.containsKey(customerId)) {
      throw const AppException('Choose a customer.');
    }
    if (lines.isEmpty) throw const AppException('Add at least one item.');
    if (dateOnly(expiryDate).isBefore(dateOnly(issueDate))) {
      throw const AppException('The expiry date can\'t be before the estimate date.');
    }
    if (_numberTaken(number, exceptId: exceptId)) {
      throw AppException('Estimate number ${number.trim()} already exists.');
    }
  }

  Future<Estimate> createEstimate({
    required String customerId,
    required String number,
    required DateTime issueDate,
    required DateTime expiryDate,
    required List<InvoiceLine> lines,
    String notes = '',
  }) async {
    _validate(
        number: number,
        customerId: customerId,
        issueDate: issueDate,
        expiryDate: expiryDate,
        lines: lines);
    return _db.transaction({DbTable.estimates}, () {
      final e = Estimate(
        id: _db.newId('e'),
        number: number.trim(),
        customerId: customerId,
        issueDate: dateOnly(issueDate),
        expiryDate: dateOnly(expiryDate),
        lines: List.unmodifiable(lines),
        notes: notes.trim(),
      );
      _db.estimates[e.id] = e;
      _db.estimateCounter++;
      return e;
    });
  }

  /// Edits an estimate that hasn't been invoiced. Editing clears the
  /// customer's answer, because they answered a different quote.
  Future<Estimate> updateEstimate({
    required String id,
    required String customerId,
    required DateTime issueDate,
    required DateTime expiryDate,
    required List<InvoiceLine> lines,
    String notes = '',
  }) async {
    final current = _openEstimate(id);
    _validate(
        number: current.number,
        customerId: customerId,
        issueDate: issueDate,
        expiryDate: expiryDate,
        lines: lines,
        exceptId: id);
    final changedTerms =
        current.customerId != customerId || !_sameLines(current.lines, lines);
    return _db.transaction({DbTable.estimates}, () {
      final e = current.copyWith(
        customerId: customerId,
        issueDate: dateOnly(issueDate),
        expiryDate: dateOnly(expiryDate),
        lines: List.unmodifiable(lines),
        notes: notes.trim(),
        clearDecision: changedTerms,
      );
      _db.estimates[id] = e;
      return e;
    });
  }

  /// Records the customer's answer; null puts it back to "awaiting reply".
  Future<void> setDecision(String id, EstimateDecision? decision) async {
    final current = _openEstimate(id);
    _db.transaction({DbTable.estimates}, () {
      _db.estimates[id] =
          current.copyWith(decision: decision, clearDecision: decision == null);
    });
  }

  Future<void> deleteEstimate(String id) async {
    _openEstimate(id);
    _db.transaction({DbTable.estimates}, () => _db.estimates.remove(id));
  }

  /// Copies an estimate (any status) as a new one dated today.
  Future<Estimate> duplicate(String id) async {
    final source = _db.estimates[id];
    if (source == null) throw const AppException('Estimate not found.');
    final validDays = source.expiryDate.difference(source.issueDate).inDays;
    return createEstimate(
      customerId: source.customerId,
      number: await nextEstimateNumber(),
      issueDate: _db.today,
      expiryDate: _db.today.add(Duration(days: validDays)),
      lines: source.lines,
      notes: source.notes,
    );
  }

  static bool _sameLines(List<InvoiceLine> a, List<InvoiceLine> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Estimate _openEstimate(String id) {
    final e = _db.estimates[id];
    if (e == null) throw const AppException('Estimate not found.');
    if (e.isConverted) {
      throw const AppException('This estimate has been invoiced and can\'t be changed.');
    }
    return e;
  }
}
