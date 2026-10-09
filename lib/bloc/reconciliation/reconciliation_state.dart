part of 'reconciliation_bloc.dart';

class ReconciliationState extends Equatable {
  const ReconciliationState({
    this.status = LoadStatus.initial,
    this.reconciliations = const [],
    this.lastCompletedId,
    this.error,
  });

  final LoadStatus status;

  /// Newest statement first.
  final List<Reconciliation> reconciliations;

  /// Set after a reconciliation is completed (the page listens for it).
  final String? lastCompletedId;
  final String? error;

  List<Reconciliation> forAccount(String account) =>
      reconciliations.where((r) => r.account == account).toList();

  Reconciliation? latestFor(String account) {
    final list = forAccount(account);
    return list.isEmpty ? null : list.first;
  }

  ReconciliationState copyWith({
    LoadStatus? status,
    List<Reconciliation>? reconciliations,
    String? lastCompletedId,
    String? error,
  }) =>
      ReconciliationState(
        status: status ?? this.status,
        reconciliations: reconciliations ?? this.reconciliations,
        lastCompletedId: lastCompletedId ?? this.lastCompletedId,
        error: error,
      );

  @override
  List<Object?> get props => [status, reconciliations, lastCompletedId, error];
}
