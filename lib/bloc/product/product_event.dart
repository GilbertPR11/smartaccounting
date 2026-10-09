part of 'product_bloc.dart';

sealed class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object?> get props => [];
}

class LoadProducts extends ProductEvent {
  const LoadProducts();
}

class AddProduct extends ProductEvent {
  const AddProduct({required this.name, required this.price, this.tax});

  final String name;
  final double price;
  final Tax? tax;

  @override
  List<Object?> get props => [name, price, tax];
}
