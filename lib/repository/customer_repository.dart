import '../databases/local_db.dart';
import '../exception/app_exception.dart';
import '../models/customer_model.dart';

class CustomerRepository {
  CustomerRepository(this._db);

  final LocalDb _db;

  /// Fires whenever the customers table changes.
  Stream<void> get changes => _db.changes.where((t) => t == DbTable.customers);

  Future<List<Customer>> fetchCustomers() async =>
      _db.customers.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  Future<Customer> addCustomer({
    required String name,
    String email = '',
    String phone = '',
    String address = '',
  }) async {
    if (name.trim().isEmpty) throw const AppException('Customer name is required.');
    return _db.transaction({DbTable.customers}, () {
      final c = Customer(
        id: _db.newId('c'),
        name: name.trim(),
        email: email.trim(),
        phone: phone.trim(),
        address: address.trim(),
      );
      _db.customers[c.id] = c;
      return c;
    });
  }
}
