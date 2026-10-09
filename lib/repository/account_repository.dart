import '../databases/local_db.dart';
import '../exception/app_exception.dart';
import '../models/account_model.dart';
import '../models/bill_model.dart';
import '../models/product_model.dart';
import '../models/reconciliation_model.dart';
import '../models/transaction_model.dart';
import '../models/vendor_model.dart';

/// The chart of accounts.
///
/// Transactions, bill lines, receipts and vendors refer to accounts by
/// name (their "category" and "paid from" fields). So names are unique, and
/// renaming an account rewrites those references in the same write.
class AccountRepository {
  AccountRepository(this._db);

  final LocalDb _db;

  Stream<void> get changes => _db.changes.where((t) => t == DbTable.accounts);

  /// By code, then name.
  Future<List<Account>> fetchAccounts() async => _db.chart.values.toList()
    ..sort((a, b) {
      final byCode = a.code.compareTo(b.code);
      return byCode != 0 ? byCode : a.name.compareTo(b.name);
    });

  void _checkUnique({required String name, required String code, String? exceptId}) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) throw const AppException('Account name is required.');
    if (_db.chart.values.any((a) => a.id != exceptId && a.name.toLowerCase() == n)) {
      throw AppException('There is already an account called "${name.trim()}".');
    }
    final c = code.trim();
    if (c.isNotEmpty && _db.chart.values.any((a) => a.id != exceptId && a.code == c)) {
      throw AppException('Account code $c is already used.');
    }
  }

  Future<Account> addAccount({
    required String name,
    required AccountType type,
    String code = '',
    String description = '',
    bool isMoney = false,
  }) async {
    _checkUnique(name: name, code: code);
    if (isMoney && type != AccountType.asset) {
      throw const AppException('Only an asset can be a bank or cash account.');
    }
    return _db.transaction({DbTable.accounts}, () {
      final a = Account(
        id: _db.newId('a'),
        code: code.trim(),
        name: name.trim(),
        type: type,
        description: description.trim(),
        isMoney: isMoney,
      );
      _db.chart[a.id] = a;
      return a;
    });
  }

  /// Renames (with references updated everywhere), recodes or re-describes.
  Future<Account> updateAccount({
    required String id,
    required String name,
    String code = '',
    String description = '',
  }) async {
    final current = _db.chart[id];
    if (current == null) throw const AppException('Account not found.');
    _checkUnique(name: name, code: code, exceptId: id);
    final oldName = current.name;
    final newName = name.trim();
    final renamed = oldName != newName;

    return _db.transaction({
      DbTable.accounts,
      if (renamed) ...{
        DbTable.transactions,
        DbTable.bills,
        DbTable.receipts,
        DbTable.vendors,
        DbTable.products,
        DbTable.reconciliations,
      },
    }, () {
      final updated = current.copyWith(
          name: newName, code: code.trim(), description: description.trim());
      _db.chart[id] = updated;
      if (renamed) _renameReferences(oldName, newName);
      return updated;
    });
  }

  void _renameReferences(String from, String to) {
    String swap(String value) => value == from ? to : value;

    for (final t in _db.transactions.values.toList()) {
      final touched = t.category == from ||
          t.account == from ||
          t.splits.any((s) => s.category == from);
      if (!touched) continue;
      _db.transactions[t.id] = t.copyWith(
        category: swap(t.category),
        account: swap(t.account),
        splits: [
          for (final s in t.splits)
            s.category == from
                ? TransactionSplit(category: to, amount: s.amount, memo: s.memo)
                : s,
        ],
      );
    }
    for (final b in _db.bills.values.toList()) {
      if (!b.lines.any((l) => l.category == from)) continue;
      _db.bills[b.id] = Bill(
        id: b.id,
        vendorId: b.vendorId,
        number: b.number,
        issueDate: b.issueDate,
        dueDate: b.dueDate,
        lines: [
          for (final l in b.lines)
            l.category == from
                ? BillLine(description: l.description, category: to, amount: l.amount, tax: l.tax)
                : l,
        ],
        notes: b.notes,
        amountPaid: b.amountPaid,
      );
    }
    for (final r in _db.receipts.values.toList()) {
      if (r.category != from && r.account != from) continue;
      _db.receipts[r.id] = r.copyWith(
        category: r.category == null ? null : swap(r.category!),
        account: r.account == null ? null : swap(r.account!),
      );
    }
    for (final p in _db.products.values.toList()) {
      if (p.expenseCategory != from) continue;
      _db.products[p.id] = Product(
        id: p.id,
        name: p.name,
        description: p.description,
        price: p.price,
        tax: p.tax,
        sold: p.sold,
        bought: p.bought,
        purchasePrice: p.purchasePrice,
        expenseCategory: to,
      );
    }
    for (final r in _db.reconciliations.values.toList()) {
      if (r.account != from) continue;
      _db.reconciliations[r.id] = Reconciliation(
        id: r.id,
        account: to,
        statementDate: r.statementDate,
        endingBalance: r.endingBalance,
        transactionIds: r.transactionIds,
        completedOn: r.completedOn,
      );
    }
    for (final v in _db.vendors.values.toList()) {
      if (v.defaultCategory != from) continue;
      _db.vendors[v.id] = Vendor(
        id: v.id,
        name: v.name,
        email: v.email,
        phone: v.phone,
        address: v.address,
        defaultCategory: to,
      );
    }
  }

  /// Archived accounts disappear from pickers but stay in old records and
  /// reports. Accounts the app posts to can't be archived, and at least one
  /// bank or cash account must stay active.
  Future<void> setArchived(String id, bool archived) async {
    final current = _db.chart[id];
    if (current == null) throw const AppException('Account not found.');
    if (archived && current.isSystem) {
      throw const AppException('The app posts to this account automatically, so it '
          'can\'t be archived. You can rename it.');
    }
    if (archived &&
        current.isMoney &&
        _db.chart.values.where((a) => a.isMoney && !a.archived).length <= 1) {
      throw const AppException('Keep at least one bank or cash account.');
    }
    _db.transaction({DbTable.accounts}, () {
      _db.chart[id] = current.copyWith(archived: archived);
    });
  }
}
