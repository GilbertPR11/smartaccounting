import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/estimate_model.dart';
import '../../repository/estimate_repository.dart';
import '../load_status.dart';

part 'estimate_event.dart';
part 'estimate_state.dart';

/// Estimate list, plus the one-tap actions (accept, decline, delete).
/// Creating and editing go through EstimateFormBloc.
class EstimateBloc extends Bloc<EstimateEvent, EstimateState> {
  EstimateBloc({required EstimateRepository repository})
      : _repository = repository,
        super(const EstimateState()) {
    on<LoadEstimates>(_onLoad);
    on<SetEstimateDecision>(_onDecision);
    on<DeleteEstimate>(_onDelete);
    _changes = _repository.changes.listen((_) => add(const LoadEstimates()));
  }

  final EstimateRepository _repository;
  late final StreamSubscription<void> _changes;

  Future<void> _onLoad(LoadEstimates event, Emitter<EstimateState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final estimates = await _repository.fetchEstimates();
      final next = await _repository.nextEstimateNumber();
      emit(state.copyWith(
          status: LoadStatus.success, estimates: estimates, nextNumber: next));
    } on AppException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  Future<void> _onDecision(SetEstimateDecision event, Emitter<EstimateState> emit) async {
    try {
      await _repository.setDecision(event.estimateId, event.decision);
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> _onDelete(DeleteEstimate event, Emitter<EstimateState> emit) async {
    try {
      await _repository.deleteEstimate(event.estimateId);
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
