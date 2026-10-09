import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/receipt_model.dart';
import '../../repository/receipt_repository.dart';
import '../load_status.dart';

part 'receipt_event.dart';
part 'receipt_state.dart';

/// Receipt inbox. Adding a photo goes through the repository directly
/// (the page needs the new receipt's id to open it); everything after that
/// goes through here.
class ReceiptBloc extends Bloc<ReceiptEvent, ReceiptState> {
  ReceiptBloc({required ReceiptRepository repository})
      : _repository = repository,
        super(const ReceiptState()) {
    on<LoadReceipts>(_onLoad);
    on<SaveReceiptDetails>((e, emit) => _run(emit, ReceiptAction.saved,
        () => _repository.updateDetails(e.receipt)));
    on<RecordReceipt>((e, emit) => _run(emit, ReceiptAction.recorded,
        () => _repository.recordAsExpense(e.receipt)));
    on<DeleteReceipt>((e, emit) => _run(emit, ReceiptAction.deleted,
        () => _repository.deleteReceipt(e.receiptId)));
    _changes = _repository.changes.listen((_) => add(const LoadReceipts()));
  }

  final ReceiptRepository _repository;
  late final StreamSubscription<void> _changes;

  Future<void> _onLoad(LoadReceipts event, Emitter<ReceiptState> emit) async {
    try {
      final receipts = await _repository.fetchReceipts();
      emit(state.copyWith(status: LoadStatus.success, receipts: receipts, action: state.action));
    } on AppException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  Future<void> _run(
      Emitter<ReceiptState> emit, ReceiptAction done, Future<void> Function() work) async {
    emit(state.copyWith(action: ReceiptAction.working));
    try {
      await work();
      emit(state.copyWith(action: done, actionCount: state.actionCount + 1));
    } on AppException catch (e) {
      emit(state.copyWith(
          action: ReceiptAction.failed, actionCount: state.actionCount + 1, error: e.message));
    }
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
