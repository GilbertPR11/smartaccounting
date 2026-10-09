import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/bill_model.dart';
import '../../repository/bill_repository.dart';
import '../load_status.dart';

part 'bill_event.dart';
part 'bill_state.dart';

/// Bill list + paying bills. Creating a bill has its own BillFormBloc.
class BillBloc extends Bloc<BillEvent, BillState> {
  BillBloc({required BillRepository repository})
      : _repository = repository,
        super(const BillState()) {
    on<LoadBills>(_onLoad);
    on<PayBill>(_onPay);
    _changes = _repository.changes.listen((_) => add(const LoadBills()));
  }

  final BillRepository _repository;
  late final StreamSubscription<void> _changes;

  Future<void> _onLoad(LoadBills event, Emitter<BillState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final bills = await _repository.fetchBills();
      emit(state.copyWith(status: LoadStatus.success, bills: bills));
    } on AppException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  Future<void> _onPay(PayBill event, Emitter<BillState> emit) async {
    try {
      await _repository.recordPayment(
        billId: event.billId,
        amount: event.amount,
        date: event.date,
        account: event.account,
      );
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
