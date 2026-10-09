import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/recurring_invoice_model.dart';
import '../../repository/recurring_repository.dart';
import '../load_status.dart';

part 'recurring_event.dart';
part 'recurring_state.dart';

/// Recurring schedules. The app adds `LoadRecurring(catchUp: true)` once at
/// start-up, which issues every invoice that came due while it was closed.
class RecurringBloc extends Bloc<RecurringEvent, RecurringState> {
  RecurringBloc({required RecurringRepository repository})
      : _repository = repository,
        super(const RecurringState()) {
    on<LoadRecurring>(_onLoad);
    on<PauseRecurring>(_onPause);
    on<DeleteRecurring>(_onDelete);
    _changes = _repository.changes.listen((_) => add(const LoadRecurring()));
  }

  final RecurringRepository _repository;
  late final StreamSubscription<void> _changes;

  Future<void> _onLoad(LoadRecurring event, Emitter<RecurringState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final issued = event.catchUp ? (await _repository.issueDue()).length : null;
      final schedules = await _repository.fetchSchedules();
      emit(state.copyWith(
        status: LoadStatus.success,
        schedules: schedules,
        issuedOnStart: issued,
      ));
    } on AppException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  Future<void> _onPause(PauseRecurring event, Emitter<RecurringState> emit) async {
    try {
      await _repository.setPaused(event.scheduleId, event.paused);
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> _onDelete(DeleteRecurring event, Emitter<RecurringState> emit) async {
    try {
      await _repository.deleteSchedule(event.scheduleId);
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
