part of 'journal_form_bloc.dart';

sealed class JournalFormEvent extends Equatable {
  const JournalFormEvent();

  @override
  List<Object?> get props => [];
}

class SubmitJournal extends JournalFormEvent {
  const SubmitJournal({
    this.journalId,
    required this.date,
    required this.description,
    required this.lines,
  });

  /// Null to create; set to update that entry.
  final String? journalId;
  final DateTime date;
  final String description;
  final List<JournalLine> lines;

  @override
  List<Object?> get props => [journalId, date, description, lines];
}
