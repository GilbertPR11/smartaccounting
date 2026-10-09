part of 'reconciliation_bloc.dart';

sealed class ReconciliationEvent extends Equatable {
  const ReconciliationEvent();

  @override
  List<Object?> get props => [];
}

class LoadReconciliations extends ReconciliationEvent {
  const LoadReconciliations();
}

class CompleteReconciliation extends ReconciliationEvent {
  const CompleteReconciliation({
    required this.account,
    required this.statementDate,
    required this.endingBalance,
    required this.transactionIds,
  });

  final String account;
  final DateTime statementDate;
  final double endingBalance;
  final List<String> transactionIds;

  @override
  List<Object?> get props => [account, statementDate, endingBalance, transactionIds];
}

class UndoReconciliation extends ReconciliationEvent {
  const UndoReconciliation(this.reconciliationId);

  final String reconciliationId;

  @override
  List<Object?> get props => [reconciliationId];
}
