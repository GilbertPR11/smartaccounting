import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/journal_model.dart';
import '../../repository/journal_repository.dart';
import '../form_save_status.dart';

export '../form_save_status.dart';

part 'journal_form_event.dart';
part 'journal_form_state.dart';

/// Saves one journal entry form (new or edit). Created per form page.
class JournalFormBloc extends Bloc<JournalFormEvent, JournalFormState> {
  JournalFormBloc({required JournalRepository repository})
      : _repository = repository,
        super(const JournalFormState()) {
    on<SubmitJournal>(_onSubmit);
  }

  final JournalRepository _repository;

  Future<void> _onSubmit(SubmitJournal event, Emitter<JournalFormState> emit) async {
    if (state.status == FormSaveStatus.submitting) return;
    emit(const JournalFormState(status: FormSaveStatus.submitting));
    try {
      final id = event.journalId;
      final saved = id == null
          ? await _repository.createJournal(
              date: event.date, description: event.description, lines: event.lines)
          : await _repository.updateJournal(
              id: id, date: event.date, description: event.description, lines: event.lines);
      emit(JournalFormState(status: FormSaveStatus.success, saved: saved));
    } on AppException catch (e) {
      emit(JournalFormState(status: FormSaveStatus.failure, error: e.message));
    }
  }
}
