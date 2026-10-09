import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/tag_model.dart';
import '../../models/transaction_model.dart';
import '../../repository/transaction_repository.dart';
import '../load_status.dart';

part 'transaction_event.dart';
part 'transaction_state.dart';

/// Bank and cash transactions plus tags. Creating and editing go through
/// TransactionFormBloc; deleting is an event here.
class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  TransactionBloc({required TransactionRepository repository})
      : _repository = repository,
        super(const TransactionState()) {
    on<LoadTransactions>(_onLoad);
    on<DeleteTransaction>(_onDelete);
    _changes = _repository.changes.listen((_) => add(const LoadTransactions()));
    _tagChanges = _repository.tagChanges.listen((_) => add(const LoadTransactions()));
  }

  final TransactionRepository _repository;
  late final StreamSubscription<void> _changes;
  late final StreamSubscription<void> _tagChanges;

  Future<void> _onLoad(LoadTransactions event, Emitter<TransactionState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final transactions = await _repository.fetchTransactions();
      final tags = await _repository.fetchTags();
      emit(state.copyWith(status: LoadStatus.success, transactions: transactions, tags: tags));
    } on AppException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  Future<void> _onDelete(DeleteTransaction event, Emitter<TransactionState> emit) async {
    try {
      await _repository.deleteTransaction(event.transactionId);
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    await _tagChanges.cancel();
    return super.close();
  }
}
