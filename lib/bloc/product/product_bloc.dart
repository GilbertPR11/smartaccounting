import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../exception/app_exception.dart';
import '../../models/product_model.dart';
import '../../models/tax_model.dart';
import '../../repository/product_repository.dart';
import '../load_status.dart';

part 'product_event.dart';
part 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  ProductBloc({required ProductRepository repository})
      : _repository = repository,
        super(const ProductState()) {
    on<LoadProducts>(_onLoad);
    on<AddProduct>(_onAdd);
    _changes = _repository.changes.listen((_) => add(const LoadProducts()));
  }

  final ProductRepository _repository;
  late final StreamSubscription<void> _changes;

  Future<void> _onLoad(LoadProducts event, Emitter<ProductState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final products = await _repository.fetchProducts();
      emit(state.copyWith(status: LoadStatus.success, products: products));
    } on AppException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  /// The list refreshes via the change stream; nothing to emit on success.
  Future<void> _onAdd(AddProduct event, Emitter<ProductState> emit) async {
    try {
      await _repository.addProduct(name: event.name, price: event.price, tax: event.tax);
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
