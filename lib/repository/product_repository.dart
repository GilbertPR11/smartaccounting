import '../databases/local_db.dart';
import '../exception/app_exception.dart';
import '../models/product_model.dart';
import '../models/tax_model.dart';
import '../utils/format.dart';

class ProductRepository {
  ProductRepository(this._db);

  final LocalDb _db;

  Stream<void> get changes => _db.changes.where((t) => t == DbTable.products);

  Future<List<Product>> fetchProducts() async => _db.products.values.toList();

  Future<Product> addProduct({
    required String name,
    String description = '',
    required double price,
    Tax? tax,
  }) async {
    if (name.trim().isEmpty) throw const AppException('Product name is required.');
    if (price < 0) throw const AppException('Price cannot be negative.');
    return _db.transaction({DbTable.products}, () {
      final p = Product(
        id: _db.newId('p'),
        name: name.trim(),
        description: description.trim(),
        price: round2(price),
        tax: tax,
      );
      _db.products[p.id] = p;
      return p;
    });
  }
}
