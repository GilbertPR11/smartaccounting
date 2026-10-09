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
    bool sold = true,
    bool bought = false,
    double? purchasePrice,
    String? expenseCategory,
  }) async {
    if (name.trim().isEmpty) throw const AppException('Product name is required.');
    if (price < 0 || (purchasePrice ?? 0) < 0) {
      throw const AppException('Prices cannot be negative.');
    }
    if (!sold && !bought) {
      throw const AppException('Choose whether you sell this, buy it, or both.');
    }
    if (bought && (expenseCategory == null || expenseCategory.trim().isEmpty)) {
      throw const AppException('Choose the expense category for what you buy.');
    }
    return _db.transaction({DbTable.products}, () {
      final p = Product(
        id: _db.newId('p'),
        name: name.trim(),
        description: description.trim(),
        price: round2(price),
        tax: tax,
        sold: sold,
        bought: bought,
        purchasePrice: purchasePrice == null ? null : round2(purchasePrice),
        expenseCategory: bought ? expenseCategory : null,
      );
      _db.products[p.id] = p;
      return p;
    });
  }
}
