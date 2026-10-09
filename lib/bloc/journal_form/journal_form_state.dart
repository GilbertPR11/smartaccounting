part of 'journal_form_bloc.dart';

class JournalFormState extends Equatable {
  const JournalFormState({this.status = FormSaveStatus.editing, this.saved, this.error});

  final FormSaveStatus status;
  final JournalEntry? saved;
  final String? error;

  @override
  List<Object?> get props => [status, saved, error];
}
