part of 'transaction_bloc.dart';

class TransactionState extends Equatable {
  const TransactionState({
    this.status = LoadStatus.initial,
    this.transactions = const [],
    this.error,
  });

  final LoadStatus status;

  /// Newest first.
  final List<BankTransaction> transactions;
  final String? error;

  /// Money received that can still be turned into an invoice.
  List<BankTransaction> get invoiceable =>
      transactions.where((t) => t.isInvoiceable).toList();

  BankTransaction? byId(String? id) {
    for (final t in transactions) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Payments recorded against [invoiceId], excluding the source transaction.
  List<BankTransaction> paymentsFor(String invoiceId, {String? excludeId}) =>
      transactions.where((t) => t.invoiceId == invoiceId && t.id != excludeId).toList();

  TransactionState copyWith({
    LoadStatus? status,
    List<BankTransaction>? transactions,
    String? error,
  }) =>
      TransactionState(
        status: status ?? this.status,
        transactions: transactions ?? this.transactions,
        error: error,
      );

  @override
  List<Object?> get props => [status, transactions, error];
}
