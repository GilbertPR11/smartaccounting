part of 'transaction_form_bloc.dart';

sealed class TransactionFormEvent extends Equatable {
  const TransactionFormEvent();

  @override
  List<Object?> get props => [];
}

class SubmitTransaction extends TransactionFormEvent {
  const SubmitTransaction({
    this.transactionId,
    required this.type,
    required this.date,
    required this.description,
    required this.amount,
    required this.account,
    this.category = '',
    this.splits = const [],
    this.tagIds = const [],
    this.notes = '',
  });

  /// Null to create; set to update that transaction.
  final String? transactionId;
  final TransactionType type;
  final DateTime date;
  final String description;
  final double amount;
  final String account;
  final String category;
  final List<TransactionSplit> splits;
  final List<String> tagIds;
  final String notes;

  @override
  List<Object?> get props => [
        transactionId,
        type,
        date,
        description,
        amount,
        account,
        category,
        splits,
        tagIds,
        notes,
      ];
}
