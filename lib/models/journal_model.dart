import 'package:equatable/equatable.dart';

import '../utils/format.dart';

/// One side of a journal entry. Exactly one of [debit] / [credit] is used.
class JournalLine extends Equatable {
  const JournalLine({
    required this.accountId,
    this.debit = 0,
    this.credit = 0,
    this.memo = '',
  });

  final String accountId;
  final double debit;
  final double credit;
  final String memo;

  /// Debit minus credit.
  double get net => round2(debit - credit);

  @override
  List<Object?> get props => [accountId, debit, credit, memo];
}

/// Where a ledger entry came from, so reports can link back to it.
enum JournalSource { manual, opening, invoice, invoicePayment, bill, billPayment, transaction }

/// A balanced set of debits and credits on one date.
///
/// Only manual entries are stored. Everything else is derived from invoices,
/// bills and transactions by utils/ledger.dart each time it's needed.
class JournalEntry extends Equatable {
  const JournalEntry({
    required this.id,
    required this.date,
    required this.description,
    required this.lines,
    this.source = JournalSource.manual,
    this.sourceId,
  });

  final String id;
  final DateTime date;
  final String description;
  final List<JournalLine> lines;
  final JournalSource source;

  /// The invoice / bill / transaction this entry was derived from.
  final String? sourceId;

  double get totalDebit => round2(lines.fold<double>(0, (s, l) => s + l.debit));
  double get totalCredit => round2(lines.fold<double>(0, (s, l) => s + l.credit));
  bool get isBalanced => (totalDebit - totalCredit).abs() < 0.005;

  @override
  List<Object?> get props => [id, date, description, lines, source, sourceId];
}
