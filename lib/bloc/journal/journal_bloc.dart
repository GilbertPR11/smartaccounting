import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/journal_model.dart';
import '../../repository/journal_repository.dart';
import '../load_status.dart';

part 'journal_event.dart';
part 'journal_state.dart';

/// Manual journal entries. Saving goes through JournalFormBloc.
class JournalBloc extends Bloc<JournalEvent, JournalState> {
  JournalBloc({required JournalRepository repository})
      : _repository = repository,
        super(const JournalState()) {
    on<LoadJournals>(_onLoad);
    on<DeleteJournal>(_onDelete);
    _changes = _repository.changes.listen((_) => add(const LoadJournals()));
  }

  final JournalRepository _repository;
  late final StreamSubscription<void> _changes;

  Future<void> _onLoad(LoadJournals event, Emitter<JournalState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final journals = await _repository.fetchJournals();
      emit(state.copyWith(status: LoadStatus.success, journals: journals));
    } on AppException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  Future<void> _onDelete(DeleteJournal event, Emitter<JournalState> emit) async {
    try {
      await _repository.deleteJournal(event.journalId);
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
