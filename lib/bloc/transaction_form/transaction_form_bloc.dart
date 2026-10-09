import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/transaction_model.dart';
import '../../repository/transaction_repository.dart';
import '../form_save_status.dart';

export '../form_save_status.dart';

part 'transaction_form_event.dart';
part 'transaction_form_state.dart';

/// Saves one transaction form (new or edit). Created per form page.
class TransactionFormBloc extends Bloc<TransactionFormEvent, TransactionFormState> {
  TransactionFormBloc({required TransactionRepository repository})
      : _repository = repository,
        super(const TransactionFormState()) {
    on<SubmitTransaction>(_onSubmit);
  }

  final TransactionRepository _repository;

  Future<void> _onSubmit(SubmitTransaction event, Emitter<TransactionFormState> emit) async {
    if (state.status == FormSaveStatus.submitting) return;
    emit(const TransactionFormState(status: FormSaveStatus.submitting));
    try {
      final id = event.transactionId;
      final saved = id == null
          ? await _repository.createTransaction(
              type: event.type,
              date: event.date,
              description: event.description,
              amount: event.amount,
              account: event.account,
              category: event.category,
              splits: event.splits,
              tagIds: event.tagIds,
              notes: event.notes,
            )
          : await _repository.updateTransaction(
              id: id,
              type: event.type,
              date: event.date,
              description: event.description,
              amount: event.amount,
              account: event.account,
              category: event.category,
              splits: event.splits,
              tagIds: event.tagIds,
              notes: event.notes,
            );
      emit(TransactionFormState(status: FormSaveStatus.success, saved: saved));
    } on AppException catch (e) {
      emit(TransactionFormState(status: FormSaveStatus.failure, error: e.message));
    }
  }
}
