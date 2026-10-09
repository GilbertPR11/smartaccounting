import 'package:equatable/equatable.dart';

/// Someone you buy from and pay.
class Vendor extends Equatable {
  const Vendor({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.address = '',
    this.defaultCategory,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;

  /// Pre-fills the category on new bills from this vendor (e.g. "Rent").
  final String? defaultCategory;

  @override
  List<Object?> get props => [id, name, email, phone, address, defaultCategory];
}
