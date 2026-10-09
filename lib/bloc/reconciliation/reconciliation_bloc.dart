import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/reconciliation_model.dart';
import '../../repository/reconciliation_repository.dart';
import '../load_status.dart';

part 'reconciliation_event.dart';
part 'reconciliation_state.dart';

/// Finished reconciliations, plus completing and undoing them.
class ReconciliationBloc extends Bloc<ReconciliationEvent, ReconciliationState> {
  ReconciliationBloc({required ReconciliationRepository repository})
      : _repository = repository,
        super(const ReconciliationState()) {
    on<LoadReconciliations>(_onLoad);
    on<CompleteReconciliation>(_onComplete);
    on<UndoReconciliation>(_onUndo);
    _changes = _repository.changes.listen((_) => add(const LoadReconciliations()));
  }

  final ReconciliationRepository _repository;
  late final StreamSubscription<void> _changes;

  Future<void> _onLoad(LoadReconciliations event, Emitter<ReconciliationState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final list = await _repository.fetchReconciliations();
      emit(state.copyWith(status: LoadStatus.success, reconciliations: list));
    } on AppException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  Future<void> _onComplete(CompleteReconciliation event, Emitter<ReconciliationState> emit) async {
    try {
      final r = await _repository.complete(
        account: event.account,
        statementDate: event.statementDate,
        endingBalance: event.endingBalance,
        transactionIds: event.transactionIds,
      );
      emit(state.copyWith(lastCompletedId: r.id));
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> _onUndo(UndoReconciliation event, Emitter<ReconciliationState> emit) async {
    try {
      await _repository.undo(event.reconciliationId);
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
