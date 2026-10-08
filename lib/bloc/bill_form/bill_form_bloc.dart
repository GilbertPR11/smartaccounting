import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/bill_model.dart';
import '../../repository/bill_repository.dart';

part 'bill_form_event.dart';
part 'bill_form_state.dart';

/// Submits one bill form; success carries the created bill.
class BillFormBloc extends Bloc<BillFormEvent, BillFormState> {
  BillFormBloc({required BillRepository repository})
      : _repository = repository,
        super(const BillFormState()) {
    on<SubmitBill>(_onSubmit);
  }

  final BillRepository _repository;

  Future<void> _onSubmit(SubmitBill event, Emitter<BillFormState> emit) async {
    if (state.status == BillFormStatus.submitting) return;
    emit(const BillFormState(status: BillFormStatus.submitting));
    try {
      final bill = await _repository.createBill(
        vendorId: event.vendorId,
        number: event.number,
        issueDate: event.issueDate,
        dueDate: event.dueDate,
        lines: event.lines,
        notes: event.notes,
        receiptId: event.receiptId,
      );
      emit(BillFormState(status: BillFormStatus.success, created: bill));
    } on AppException catch (e) {
      emit(BillFormState(status: BillFormStatus.failure, error: e.message));
    }
  }
}
