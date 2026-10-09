import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/invoice_model.dart';
import '../../models/recurring_invoice_model.dart';
import '../../repository/recurring_repository.dart';
import '../form_save_status.dart';

export '../form_save_status.dart';

part 'recurring_form_event.dart';
part 'recurring_form_state.dart';

/// Saves one recurring-schedule form (new or edit). Created per form page.
class RecurringFormBloc extends Bloc<RecurringFormEvent, RecurringFormState> {
  RecurringFormBloc({required RecurringRepository repository})
      : _repository = repository,
        super(const RecurringFormState()) {
    on<SubmitRecurring>(_onSubmit);
  }

  final RecurringRepository _repository;

  Future<void> _onSubmit(SubmitRecurring event, Emitter<RecurringFormState> emit) async {
    if (state.status == FormSaveStatus.submitting) return;
    emit(const RecurringFormState(status: FormSaveStatus.submitting));
    try {
      final id = event.scheduleId;
      final saved = id == null
          ? await _repository.createSchedule(
              customerId: event.customerId,
              lines: event.lines,
              frequency: event.frequency,
              startDate: event.startDate,
              endDate: event.endDate,
              maxCount: event.maxCount,
              termsDays: event.termsDays,
              notes: event.notes,
            )
          : await _repository.updateSchedule(
              id: id,
              customerId: event.customerId,
              lines: event.lines,
              frequency: event.frequency,
              startDate: event.startDate,
              endDate: event.endDate,
              maxCount: event.maxCount,
              termsDays: event.termsDays,
              notes: event.notes,
            );
      emit(RecurringFormState(status: FormSaveStatus.success, saved: saved));
    } on AppException catch (e) {
      emit(RecurringFormState(status: FormSaveStatus.failure, error: e.message));
    }
  }
}
