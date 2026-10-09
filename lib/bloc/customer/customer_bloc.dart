import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/customer_model.dart';
import '../../repository/customer_repository.dart';
import '../load_status.dart';

part 'customer_event.dart';
part 'customer_state.dart';

/// Customer list. Reloads by itself whenever the customers table changes,
/// so writes made anywhere (e.g. the "new customer" dialog) show up here.
class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  CustomerBloc({required CustomerRepository repository})
      : _repository = repository,
        super(const CustomerState()) {
    on<LoadCustomers>(_onLoad);
    _changes = _repository.changes.listen((_) => add(const LoadCustomers()));
  }

  final CustomerRepository _repository;
  late final StreamSubscription<void> _changes;

  Future<void> _onLoad(LoadCustomers event, Emitter<CustomerState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final customers = await _repository.fetchCustomers();
      emit(state.copyWith(status: LoadStatus.success, customers: customers));
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
