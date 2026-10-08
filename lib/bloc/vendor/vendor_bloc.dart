import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/vendor_model.dart';
import '../../repository/vendor_repository.dart';
import '../load_status.dart';

part 'vendor_event.dart';
part 'vendor_state.dart';

class VendorBloc extends Bloc<VendorEvent, VendorState> {
  VendorBloc({required VendorRepository repository})
      : _repository = repository,
        super(const VendorState()) {
    on<LoadVendors>(_onLoad);
    _changes = _repository.changes.listen((_) => add(const LoadVendors()));
  }

  final VendorRepository _repository;
  late final StreamSubscription<void> _changes;

  Future<void> _onLoad(LoadVendors event, Emitter<VendorState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final vendors = await _repository.fetchVendors();
      emit(state.copyWith(status: LoadStatus.success, vendors: vendors));
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
