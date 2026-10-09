part of 'recurring_form_bloc.dart';

sealed class RecurringFormEvent extends Equatable {
  const RecurringFormEvent();

  @override
  List<Object?> get props => [];
}

class SubmitRecurring extends RecurringFormEvent {
  const SubmitRecurring({
    this.scheduleId,
    required this.customerId,
    required this.lines,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.maxCount,
    required this.termsDays,
    this.notes = '',
  });

  /// Null to create; set to update that schedule.
  final String? scheduleId;
  final String customerId;
  final List<InvoiceLine> lines;
  final RecurFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final int? maxCount;
  final int termsDays;
  final String notes;

  @override
  List<Object?> get props => [
        scheduleId,
        customerId,
        lines,
        frequency,
        startDate,
        endDate,
        maxCount,
        termsDays,
        notes,
      ];
}
