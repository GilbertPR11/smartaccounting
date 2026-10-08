import '../databases/local_db.dart';
import '../exception/app_exception.dart';
import '../models/vendor_model.dart';

class VendorRepository {
  VendorRepository(this._db);

  final LocalDb _db;

  Stream<void> get changes => _db.changes.where((t) => t == DbTable.vendors);

  Future<List<Vendor>> fetchVendors() async =>
      _db.vendors.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  Future<Vendor> addVendor({
    required String name,
    String email = '',
    String phone = '',
    String address = '',
    String? defaultCategory,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const AppException('Vendor name is required.');
    if (_db.vendors.values.any((v) => v.name.toLowerCase() == trimmed.toLowerCase())) {
      throw AppException('You already have a vendor called $trimmed.');
    }
    return _db.transaction({DbTable.vendors}, () {
      final v = Vendor(
        id: _db.newId('v'),
        name: trimmed,
        email: email.trim(),
        phone: phone.trim(),
        address: address.trim(),
        defaultCategory: defaultCategory,
      );
      _db.vendors[v.id] = v;
      return v;
    });
  }
}
