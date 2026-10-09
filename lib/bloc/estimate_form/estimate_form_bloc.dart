import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/estimate_model.dart';
import '../../models/invoice_model.dart';
import '../../repository/estimate_repository.dart';
import '../form_save_status.dart';

export '../form_save_status.dart';

part 'estimate_form_event.dart';
part 'estimate_form_state.dart';

/// Saves one estimate form (new or edit). Created per form page.
class EstimateFormBloc extends Bloc<EstimateFormEvent, EstimateFormState> {
  EstimateFormBloc({required EstimateRepository repository})
      : _repository = repository,
        super(const EstimateFormState()) {
    on<SubmitEstimate>(_onSubmit);
  }

  final EstimateRepository _repository;

  Future<void> _onSubmit(SubmitEstimate event, Emitter<EstimateFormState> emit) async {
    if (state.status == FormSaveStatus.submitting) return;
    emit(const EstimateFormState(status: FormSaveStatus.submitting));
    try {
      final id = event.estimateId;
      final saved = id == null
          ? await _repository.createEstimate(
              customerId: event.customerId,
              number: event.number,
              issueDate: event.issueDate,
              expiryDate: event.expiryDate,
              lines: event.lines,
              notes: event.notes,
            )
          : await _repository.updateEstimate(
              id: id,
              customerId: event.customerId,
              issueDate: event.issueDate,
              expiryDate: event.expiryDate,
              lines: event.lines,
              notes: event.notes,
            );
      emit(EstimateFormState(status: FormSaveStatus.success, saved: saved));
    } on AppException catch (e) {
      emit(EstimateFormState(status: FormSaveStatus.failure, error: e.message));
    }
  }
}
