import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/transaction_model.dart';
import '../../repository/transaction_repository.dart';
import '../load_status.dart';

part 'transaction_event.dart';
part 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  TransactionBloc({required TransactionRepository repository})
      : _repository = repository,
        super(const TransactionState()) {
    on<LoadTransactions>(_onLoad);
    _changes = _repository.changes.listen((_) => add(const LoadTransactions()));
  }

  final TransactionRepository _repository;
  late final StreamSubscription<void> _changes;

  Future<void> _onLoad(LoadTransactions event, Emitter<TransactionState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final transactions = await _repository.fetchTransactions();
      emit(state.copyWith(status: LoadStatus.success, transactions: transactions));
    } on AppException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
