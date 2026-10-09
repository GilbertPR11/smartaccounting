part of 'invoice_form_bloc.dart';

sealed class InvoiceFormEvent extends Equatable {
  const InvoiceFormEvent();

  @override
  List<Object?> get props => [];
}

class SubmitInvoice extends InvoiceFormEvent {
  const SubmitInvoice({
    required this.customerId,
    required this.number,
    required this.issueDate,
    required this.dueDate,
    required this.lines,
    this.notes = '',
    this.sourceTransactionId,
    this.estimateId,
  });

  final String customerId;
  final String number;
  final DateTime issueDate;
  final DateTime dueDate;
  final List<InvoiceLine> lines;
  final String notes;
  final String? sourceTransactionId;

  /// Converting this estimate.
  final String? estimateId;

  @override
  List<Object?> get props =>
      [customerId, number, issueDate, dueDate, lines, notes, sourceTransactionId, estimateId];
}
