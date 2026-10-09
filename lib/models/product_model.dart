import 'package:equatable/equatable.dart';

import 'tax_model.dart';

class Product extends Equatable {
  const Product({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.tax,
  });

  final String id;
  final String name;
  final String description;
  final double price;

  /// Default tax applied when this product is added to an invoice.
  final Tax? tax;

  @override
  List<Object?> get props => [id, name, description, price, tax];
}
