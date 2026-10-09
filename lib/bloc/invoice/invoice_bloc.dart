import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/invoice_model.dart';
import '../../repository/invoice_repository.dart';
import '../load_status.dart';

part 'invoice_event.dart';
part 'invoice_state.dart';

/// Invoice list + payments. Creating an invoice has its own Bloc
/// (InvoiceFormBloc) because the form needs the created invoice back.
class InvoiceBloc extends Bloc<InvoiceEvent, InvoiceState> {
  InvoiceBloc({required InvoiceRepository repository})
      : _repository = repository,
        super(const InvoiceState()) {
    on<LoadInvoices>(_onLoad);
    on<RecordInvoicePayment>(_onRecordPayment);
    _changes = _repository.changes.listen((_) => add(const LoadInvoices()));
  }

  final InvoiceRepository _repository;
  late final StreamSubscription<void> _changes;

  Future<void> _onLoad(LoadInvoices event, Emitter<InvoiceState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final invoices = await _repository.fetchInvoices();
      final next = await _repository.nextInvoiceNumber();
      emit(state.copyWith(
          status: LoadStatus.success, invoices: invoices, nextNumber: next));
    } on AppException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  Future<void> _onRecordPayment(
      RecordInvoicePayment event, Emitter<InvoiceState> emit) async {
    try {
      await _repository.recordPayment(
        invoiceId: event.invoiceId,
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
