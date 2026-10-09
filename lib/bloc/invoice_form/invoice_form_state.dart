part of 'invoice_form_bloc.dart';

enum InvoiceFormStatus { editing, submitting, success, failure }

class InvoiceFormState extends Equatable {
  const InvoiceFormState({
    this.status = InvoiceFormStatus.editing,
    this.created,
    this.error,
  });

  final InvoiceFormStatus status;

  /// Set when [status] is success.
  final Invoice? created;
  final String? error;

  @override
  List<Object?> get props => [status, created, error];
}
