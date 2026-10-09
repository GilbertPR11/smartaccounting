part of 'recurring_form_bloc.dart';

class RecurringFormState extends Equatable {
  const RecurringFormState({
    this.status = FormSaveStatus.editing,
    this.saved,
    this.error,
  });

  final FormSaveStatus status;

  /// Set when [status] is success.
  final RecurringInvoice? saved;
  final String? error;

  @override
  List<Object?> get props => [status, saved, error];
}
