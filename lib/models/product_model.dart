import 'package:equatable/equatable.dart';

import 'tax_model.dart';

/// Something you sell, buy, or both (like Wave's "products & services").
class Product extends Equatable {
  const Product({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.tax,
    this.sold = true,
    this.bought = false,
    this.purchasePrice,
    this.expenseCategory,
  });

  final String id;
  final String name;
  final String description;

  /// Selling price (used on invoices and estimates).
  final double price;

  /// Default tax applied when this product is added to an invoice or bill.
  final Tax? tax;

  /// Shown when adding lines to invoices, estimates and recurring invoices.
  final bool sold;

  /// Shown when adding lines to bills.
  final bool bought;

  /// Usual cost from the vendor (pre-fills bill lines).
  final double? purchasePrice;

  /// Expense account a bill line for this product goes to.
  final String? expenseCategory;

  @override
  List<Object?> get props =>
      [id, name, description, price, tax, sold, bought, purchasePrice, expenseCategory];
}
