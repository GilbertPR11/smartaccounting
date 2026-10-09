part of 'invoice_bloc.dart';

class InvoiceState extends Equatable {
  const InvoiceState({
    this.status = LoadStatus.initial,
    this.invoices = const [],
    this.nextNumber = '',
    this.error,
  });

  final LoadStatus status;

  /// Newest first.
  final List<Invoice> invoices;

  /// Suggested number for the next invoice.
  final String nextNumber;
  final String? error;

  Invoice? byId(String? id) {
    for (final i in invoices) {
      if (i.id == id) return i;
    }
    return null;
  }

  bool numberExists(String number) =>
      invoices.any((i) => i.number.toLowerCase() == number.trim().toLowerCase());

  InvoiceState copyWith({
    LoadStatus? status,
    List<Invoice>? invoices,
    String? nextNumber,
    String? error,
  }) =>
      InvoiceState(
        status: status ?? this.status,
        invoices: invoices ?? this.invoices,
        nextNumber: nextNumber ?? this.nextNumber,
        error: error,
      );

  @override
  List<Object?> get props => [status, invoices, nextNumber, error];
}
