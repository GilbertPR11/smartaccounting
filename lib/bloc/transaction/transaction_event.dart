part of 'transaction_bloc.dart';

sealed class TransactionEvent extends Equatable {
  const TransactionEvent();

  @override
  List<Object?> get props => [];
}

class LoadTransactions extends TransactionEvent {
  const LoadTransactions();
}

class DeleteTransaction extends TransactionEvent {
  const DeleteTransaction(this.transactionId);

  final String transactionId;

  @override
  List<Object?> get props => [transactionId];
}
