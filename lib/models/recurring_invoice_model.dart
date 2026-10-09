import 'package:equatable/equatable.dart';

import '../utils/format.dart';
import 'invoice_model.dart';

enum RecurFrequency { weekly, monthly, quarterly, yearly }

extension RecurFrequencyLabel on RecurFrequency {
  String get label => switch (this) {
        RecurFrequency.weekly => 'Weekly',
        RecurFrequency.monthly => 'Monthly',
        RecurFrequency.quarterly => 'Every 3 months',
        RecurFrequency.yearly => 'Yearly',
      };

  /// "every month" — for sentences.
  String get every => switch (this) {
        RecurFrequency.weekly => 'every week',
        RecurFrequency.monthly => 'every month',
        RecurFrequency.quarterly => 'every 3 months',
        RecurFrequency.yearly => 'every year',
      };
}

enum RecurringStatus { active, paused, ended }

extension RecurringStatusLabel on RecurringStatus {
  String get label => switch (this) {
        RecurringStatus.active => 'Active',
        RecurringStatus.paused => 'Paused',
        RecurringStatus.ended => 'Ended',
      };
}

/// A schedule that issues the same invoice on a fixed rhythm.
///
/// Occurrence dates are always computed from [startDate] (occurrence n is
/// start + n periods), never from the previous date. That way a schedule
/// starting on 31 January issues on 28/29 Feb, then 31 Mar, instead of
/// drifting to the 28th forever.
class RecurringInvoice extends Equatable {
  const RecurringInvoice({
    required this.id,
    required this.customerId,
    required this.lines,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.maxCount,
    this.termsDays = 14,
    this.notes = '',
    this.paused = false,
    this.issuedCount = 0,
  });

  final String id;
  final String customerId;
  final List<InvoiceLine> lines;
  final RecurFrequency frequency;
  final DateTime startDate;

  /// Stop after this date (inclusive), if set.
  final DateTime? endDate;

  /// Stop after this many invoices, if set.
  final int? maxCount;

  /// Each invoice is due this many days after it's issued.
  final int termsDays;
  final String notes;
  final bool paused;

  /// How many invoices the schedule has issued so far.
  final int issuedCount;

  double get total => sumTotal(lines);

  /// Date of occurrence [n] (0 = the start date).
  DateTime occurrence(int n) => switch (frequency) {
        RecurFrequency.weekly => dateOnly(startDate).add(Duration(days: 7 * n)),
        RecurFrequency.monthly => addMonths(startDate, n),
        RecurFrequency.quarterly => addMonths(startDate, 3 * n),
        RecurFrequency.yearly => addMonths(startDate, 12 * n),
      };

  /// True when no further invoice will ever be issued.
  bool get isFinished {
    final max = maxCount;
    if (max != null && issuedCount >= max) return true;
    final end = endDate;
    return end != null && occurrence(issuedCount).isAfter(dateOnly(end));
  }

  /// When the next invoice will be issued, or null if the schedule is done.
  DateTime? get nextDate => isFinished ? null : occurrence(issuedCount);

  RecurringStatus get status => isFinished
      ? RecurringStatus.ended
      : paused
          ? RecurringStatus.paused
          : RecurringStatus.active;

  /// "Monthly, 12 times" / "Weekly until 31 Dec 2026" / "Yearly".
  String get rhythm {
    final max = maxCount;
    final end = endDate;
    if (max != null) return '${frequency.label}, $max ${max == 1 ? 'time' : 'times'}';
    if (end != null) return '${frequency.label} until ${fmtDate(end)}';
    return frequency.label;
  }

  RecurringInvoice copyWith({
    String? customerId,
    List<InvoiceLine>? lines,
    RecurFrequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    int? maxCount,
    bool clearMaxCount = false,
    int? termsDays,
    String? notes,
    bool? paused,
    int? issuedCount,
  }) =>
      RecurringInvoice(
        id: id,
        customerId: customerId ?? this.customerId,
        lines: lines ?? this.lines,
        frequency: frequency ?? this.frequency,
        startDate: startDate ?? this.startDate,
        endDate: clearEndDate ? null : (endDate ?? this.endDate),
        maxCount: clearMaxCount ? null : (maxCount ?? this.maxCount),
        termsDays: termsDays ?? this.termsDays,
        notes: notes ?? this.notes,
        paused: paused ?? this.paused,
        issuedCount: issuedCount ?? this.issuedCount,
      );

  @override
  List<Object?> get props => [
        id,
        customerId,
        lines,
        frequency,
        startDate,
        endDate,
        maxCount,
        termsDays,
        notes,
        paused,
        issuedCount,
      ];
}
