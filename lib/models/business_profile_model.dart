import 'package:equatable/equatable.dart';

/// Who the invoices are from. Shown in the invoice header.
class BusinessProfile extends Equatable {
  const BusinessProfile({
    required this.name,
    this.address = '',
    this.email = '',
    this.phone = '',
    this.registrationNo = '',
    this.sstNo = '',
  });

  static const empty = BusinessProfile(name: '');

  final String name;
  final String address;
  final String email;
  final String phone;

  /// SSM company registration number.
  final String registrationNo;

  /// SST registration number. Required on invoices once SST-registered.
  final String sstNo;

  BusinessProfile copyWith({
    String? name,
    String? address,
    String? email,
    String? phone,
    String? registrationNo,
    String? sstNo,
  }) =>
      BusinessProfile(
        name: name ?? this.name,
        address: address ?? this.address,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        registrationNo: registrationNo ?? this.registrationNo,
        sstNo: sstNo ?? this.sstNo,
      );

  @override
  List<Object?> get props => [name, address, email, phone, registrationNo, sstNo];
}
