part of 'estimate_bloc.dart';

sealed class EstimateEvent extends Equatable {
  const EstimateEvent();

  @override
  List<Object?> get props => [];
}

class LoadEstimates extends EstimateEvent {
  const LoadEstimates();
}

/// Null [decision] puts the estimate back to "awaiting reply".
class SetEstimateDecision extends EstimateEvent {
  const SetEstimateDecision(this.estimateId, this.decision);

  final String estimateId;
  final EstimateDecision? decision;

  @override
  List<Object?> get props => [estimateId, decision];
}

class DeleteEstimate extends EstimateEvent {
  const DeleteEstimate(this.estimateId);

  final String estimateId;

  @override
  List<Object?> get props => [estimateId];
}
