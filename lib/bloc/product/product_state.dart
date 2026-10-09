part of 'product_bloc.dart';

class ProductState extends Equatable {
  const ProductState({
    this.status = LoadStatus.initial,
    this.products = const [],
    this.error,
  });

  final LoadStatus status;
  final List<Product> products;
  final String? error;

  /// For invoices, estimates and recurring invoices.
  List<Product> get sold => products.where((p) => p.sold).toList();

  /// For bills.
  List<Product> get bought => products.where((p) => p.bought).toList();

  ProductState copyWith({LoadStatus? status, List<Product>? products, String? error}) =>
      ProductState(
        status: status ?? this.status,
        products: products ?? this.products,
        error: error,
      );

  @override
  List<Object?> get props => [status, products, error];
}
