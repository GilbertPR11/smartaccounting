import '../databases/local_db.dart';
import '../exception/app_exception.dart';
import '../models/account_model.dart';
import '../models/tag_model.dart';
import '../models/transaction_model.dart';
import '../utils/csv_import.dart';
import '../utils/format.dart';

/// Bank and cash transactions, and their tags.
///
/// Payments of invoices and bills, and expenses recorded from receipts, are
/// created by their own repositories. Here they can only get a new
/// description, notes and tags; deleting a payment also takes it off its
/// invoice or bill.
class TransactionRepository {
  TransactionRepository(this._db);

  final LocalDb _db;

  Stream<void> get changes => _db.changes.where((t) => t == DbTable.transactions);
  Stream<void> get tagChanges => _db.changes.where((t) => t == DbTable.tags);

  /// Newest first.
  Future<List<BankTransaction>> fetchTransactions() async =>
      _db.transactions.values.toList()..sort((a, b) => b.date.compareTo(a.date));

  Future<List<Tag>> fetchTags() async =>
      _db.tags.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  /// Returns the existing tag if one with this name already exists.
  Future<Tag> addTag(String name) async {
    final n = name.trim();
    if (n.isEmpty) throw const AppException('Tag name is required.');
    for (final t in _db.tags.values) {
      if (t.name.toLowerCase() == n.toLowerCase()) return t;
    }
    return _db.transaction({DbTable.tags}, () {
      final t = Tag(id: _db.newId('g'), name: n);
      _db.tags[t.id] = t;
      return t;
    });
  }

  /// The chart's exact spelling of a category, or an error. Bank and cash
  /// accounts aren't categories (use Transfer Clearing to move money
  /// between your own accounts).
  String _category(String name) {
    final n = name.trim().toLowerCase();
    for (final a in _db.chart.values) {
      if (a.name.toLowerCase() != n) continue;
      if (a.isMoney) {
        throw const AppException('A bank or cash account can\'t be a category. To move '
            'money between your accounts, use "Transfer Clearing" on both sides.');
      }
      return a.name;
    }
    throw const AppException('Choose a category.');
  }

  /// Checks a transaction's money fields and returns the category and
  /// splits with the chart's exact account names.
  (String, List<TransactionSplit>) _validateMoney({
    required double amount,
    required String account,
    required String category,
    required List<TransactionSplit> splits,
  }) {
    if (amount <= 0) throw const AppException('Enter an amount above zero.');
    if (!_db.accounts.contains(account)) {
      throw const AppException('Choose a bank or cash account.');
    }
    if (splits.isEmpty) return (_category(category), const []);
    if (splits.length < 2) throw const AppException('A split needs at least two parts.');
    final clean = <TransactionSplit>[];
    for (final s in splits) {
      if (s.amount <= 0) throw const AppException('Every part of a split needs an amount.');
      if (s.category.trim().isEmpty) {
        throw const AppException('Choose a category for every part of the split.');
      }
      clean.add(TransactionSplit(
          category: _category(s.category), amount: round2(s.amount), memo: s.memo.trim()));
    }
    final total = round2(clean.fold<double>(0, (s, p) => s + p.amount));
    if ((total - round2(amount)).abs() > 0.004) {
      throw AppException('The parts add up to ${money(total)}, not ${money(amount)}.');
    }
    return ('', clean);
  }

  Future<BankTransaction> createTransaction({
    required TransactionType type,
    required DateTime date,
    required String description,
    required double amount,
    required String account,
    String category = '',
    List<TransactionSplit> splits = const [],
    List<String> tagIds = const [],
    String notes = '',
  }) async {
    if (description.trim().isEmpty) throw const AppException('Add a description.');
    final (cleanCategory, cleanSplits) =
        _validateMoney(amount: amount, account: account, category: category, splits: splits);
    return _db.transaction({DbTable.transactions}, () {
      final t = BankTransaction(
        id: _db.newId('t'),
        date: dateOnly(date),
        description: description.trim(),
        amount: round2(amount),
        type: type,
        account: account,
        category: cleanCategory,
        splits: List.unmodifiable(cleanSplits),
        tagIds: List.unmodifiable(tagIds),
        notes: notes.trim(),
      );
      _db.transactions[t.id] = t;
      return t;
    });
  }

  /// Saves edits. Linked transactions only take description, notes and
  /// tags; reconciled ones keep their date, amount and account.
  Future<BankTransaction> updateTransaction({
    required String id,
    required TransactionType type,
    required DateTime date,
    required String description,
    required double amount,
    required String account,
    String category = '',
    List<TransactionSplit> splits = const [],
    List<String> tagIds = const [],
    String notes = '',
  }) async {
    final current = _db.transactions[id];
    if (current == null) throw const AppException('Transaction not found.');
    if (description.trim().isEmpty) throw const AppException('Add a description.');

    final BankTransaction updated;
    if (current.isLinked) {
      updated = current.copyWith(
          description: description.trim(), notes: notes.trim(), tagIds: tagIds);
    } else {
      final moneyChanged = current.type != type ||
          dateOnly(current.date) != dateOnly(date) ||
          round2(current.amount) != round2(amount) ||
          current.account != account;
      if (current.reconciled && moneyChanged) {
        throw const AppException('This transaction is reconciled, so its date, amount '
            'and account are locked. You can still change the category.');
      }
      final (cleanCategory, cleanSplits) =
          _validateMoney(amount: amount, account: account, category: category, splits: splits);
      updated = current.copyWith(
        type: type,
        date: dateOnly(date),
        description: description.trim(),
        amount: round2(amount),
        account: account,
        category: cleanCategory,
        splits: List.unmodifiable(cleanSplits),
        tagIds: List.unmodifiable(tagIds),
        notes: notes.trim(),
      );
    }
    return _db.transaction({DbTable.transactions}, () {
      _db.transactions[id] = updated;
      return updated;
    });
  }

  /// Adds statement lines as transactions in [account], categorised as
  /// "Uncategorized" so they show up for review. Returns how many.
  Future<int> importStatement(String account, List<StatementLine> lines) async {
    if (!_db.accounts.contains(account)) {
      throw const AppException('Choose a bank or cash account.');
    }
    if (lines.isEmpty) throw const AppException('Nothing to import.');
    String uncategorized(AccountRole role) =>
        _db.chart.values.firstWhere((a) => a.role == role).name;
    final income = uncategorized(AccountRole.uncategorizedIncome);
    final expense = uncategorized(AccountRole.uncategorizedExpense);

    return _db.transaction({DbTable.transactions}, () {
      for (final line in lines) {
        final t = BankTransaction(
          id: _db.newId('t'),
          date: dateOnly(line.date),
          description: line.description.trim(),
          amount: round2(line.amount.abs()),
          type: line.amount >= 0 ? TransactionType.income : TransactionType.expense,
          account: account,
          category: line.amount >= 0 ? income : expense,
          notes: 'Imported from statement',
        );
        _db.transactions[t.id] = t;
      }
      return lines.length;
    });
  }

  /// Deletes a transaction. A payment is also taken off its invoice or bill.
  Future<void> deleteTransaction(String id) async {
    final t = _db.transactions[id];
    if (t == null) throw const AppException('Transaction not found.');
    if (t.reconciled) {
      throw const AppException('Reconciled transactions can\'t be deleted. '
          'Undo the reconciliation first.');
    }
    if (t.receiptId != null) {
      throw const AppException('This expense was recorded from a receipt, which is '
          'kept as proof.');
    }
    final inv = _db.invoices[t.invoiceId];
    if (inv != null && inv.sourceTransactionId == t.id) {
      throw AppException('${inv.number} was created from this payment. '
          'It can\'t be deleted on its own.');
    }
    final bill = _db.bills[t.billId];

    _db.transaction({
      DbTable.transactions,
      if (inv != null) DbTable.invoices,
      if (bill != null) DbTable.bills,
    }, () {
      _db.transactions.remove(id);
      if (inv != null) {
        final paid = round2(inv.amountPaid - t.amount);
        _db.invoices[inv.id] = inv.copyWith(amountPaid: paid < 0 ? 0 : paid);
      }
      if (bill != null) {
        final paid = round2(bill.amountPaid - t.amount);
        _db.bills[bill.id] = bill.copyWith(amountPaid: paid < 0 ? 0 : paid);
      }
    });
  }
}
