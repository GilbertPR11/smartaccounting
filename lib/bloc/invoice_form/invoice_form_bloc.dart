import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/invoice_model.dart';
import '../../repository/invoice_repository.dart';

part 'invoice_form_event.dart';
part 'invoice_form_state.dart';

/// Submits one invoice form. Created per form page (not global).
/// Field editing stays in the page's State; this Bloc owns the save.
class InvoiceFormBloc extends Bloc<InvoiceFormEvent, InvoiceFormState> {
  InvoiceFormBloc({required InvoiceRepository repository})
      : _repository = repository,
        super(const InvoiceFormState()) {
    on<SubmitInvoice>(_onSubmit);
  }

  final InvoiceRepository _repository;

  Future<void> _onSubmit(SubmitInvoice event, Emitter<InvoiceFormState> emit) async {
    if (state.status == InvoiceFormStatus.submitting) return;
    emit(const InvoiceFormState(status: InvoiceFormStatus.submitting));
    try {
      final invoice = await _repository.createInvoice(
        customerId: event.customerId,
        number: event.number,
        issueDate: event.issueDate,
        dueDate: event.dueDate,
        lines: event.lines,
        notes: event.notes,
        sourceTransactionId: event.sourceTransactionId,
        estimateId: event.estimateId,
      );
      emit(InvoiceFormState(status: InvoiceFormStatus.success, created: invoice));
    } on AppException catch (e) {
      emit(InvoiceFormState(status: InvoiceFormStatus.failure, error: e.message));
    }
  }
}
