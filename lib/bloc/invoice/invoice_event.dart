part of 'invoice_bloc.dart';

sealed class InvoiceEvent extends Equatable {
  const InvoiceEvent();

  @override
  List<Object?> get props => [];
}

class LoadInvoices extends InvoiceEvent {
  const LoadInvoices();
}

class RecordInvoicePayment extends InvoiceEvent {
  const RecordInvoicePayment({
    required this.invoiceId,
    required this.amount,
    required this.date,
    required this.account,
  });

  final String invoiceId;
  final double amount;
  final DateTime date;
  final String account;

  @override
  List<Object?> get props => [invoiceId, amount, date, account];
}
