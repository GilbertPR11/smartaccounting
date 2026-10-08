part of 'receipt_bloc.dart';

sealed class ReceiptEvent extends Equatable {
  const ReceiptEvent();

  @override
  List<Object?> get props => [];
}

class LoadReceipts extends ReceiptEvent {
  const LoadReceipts();
}

/// Keep details, stay in "To review".
class SaveReceiptDetails extends ReceiptEvent {
  const SaveReceiptDetails(this.receipt);

  final Receipt receipt;

  @override
  List<Object?> get props => [receipt];
}

/// Record as an expense (creates the money-out transaction).
class RecordReceipt extends ReceiptEvent {
  const RecordReceipt(this.receipt);

  final Receipt receipt;

  @override
  List<Object?> get props => [receipt];
}

class DeleteReceipt extends ReceiptEvent {
  const DeleteReceipt(this.receiptId);

  final String receiptId;

  @override
  List<Object?> get props => [receiptId];
}
