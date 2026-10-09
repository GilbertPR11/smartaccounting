import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.address = '',
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;

  Customer copyWith({String? name, String? email, String? phone, String? address}) =>
      Customer(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        address: address ?? this.address,
      );

  @override
  List<Object?> get props => [id, name, email, phone, address];
}
