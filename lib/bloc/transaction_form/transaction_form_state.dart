part of 'transaction_form_bloc.dart';

class TransactionFormState extends Equatable {
  const TransactionFormState({this.status = FormSaveStatus.editing, this.saved, this.error});

  final FormSaveStatus status;
  final BankTransaction? saved;
  final String? error;

  @override
  List<Object?> get props => [status, saved, error];
}
