part of 'vendor_bloc.dart';

class VendorState extends Equatable {
  const VendorState({this.status = LoadStatus.initial, this.vendors = const [], this.error});

  final LoadStatus status;
  final List<Vendor> vendors;
  final String? error;

  Vendor? byId(String? id) {
    for (final v in vendors) {
      if (v.id == id) return v;
    }
    return null;
  }

  VendorState copyWith({LoadStatus? status, List<Vendor>? vendors, String? error}) =>
      VendorState(
        status: status ?? this.status,
        vendors: vendors ?? this.vendors,
        error: error,
      );

  @override
  List<Object?> get props => [status, vendors, error];
}
