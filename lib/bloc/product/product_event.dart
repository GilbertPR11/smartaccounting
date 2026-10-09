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
  const AddProduct({
    required this.name,
    required this.price,
    this.tax,
    this.sold = true,
    this.bought = false,
    this.purchasePrice,
    this.expenseCategory,
  });

  final String name;
  final double price;
  final Tax? tax;
  final bool sold;
  final bool bought;
  final double? purchasePrice;
  final String? expenseCategory;

  @override
  List<Object?> get props =>
      [name, price, tax, sold, bought, purchasePrice, expenseCategory];
}
