part of 'bill_form_bloc.dart';

enum BillFormStatus { editing, submitting, success, failure }

class BillFormState extends Equatable {
  const BillFormState({this.status = BillFormStatus.editing, this.created, this.error});

  final BillFormStatus status;
  final Bill? created;
  final String? error;

  @override
  List<Object?> get props => [status, created, error];
}
