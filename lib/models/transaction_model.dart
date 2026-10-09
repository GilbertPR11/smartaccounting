import 'package:equatable/equatable.dart';

import '../config/constants.dart';
import '../utils/format.dart';

enum TransactionType { income, expense }

/// Part of a split transaction: this much of it belongs to this category.
class TransactionSplit extends Equatable {
  const TransactionSplit({required this.category, required this.amount, this.memo = ''});

  /// An account name from the chart of accounts.
  final String category;

  /// Always positive.
  final double amount;
  final String memo;

  @override
  List<Object?> get props => [category, amount, memo];
}

/// A bank/cash movement. Named `BankTransaction` (not `Transaction`) so it
/// won't clash with sqflite's `Transaction` when the real database lands.
///
/// An income transaction can be linked to an invoice, either because the
/// invoice was created from it, or because it was recorded as a payment.
class BankTransaction extends Equatable {
  const BankTransaction({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    required this.account,
    required this.category,
    this.customerId,
    this.invoiceId,
    this.billId,
    this.receiptId,
    this.splits = const [],
    this.tagIds = const [],
    this.notes = '',
    this.reconciled = false,
  });

  final String id;
  final DateTime date;
  final String description;

  /// Always positive; the sign comes from [type].
  final double amount;
  final TransactionType type;

  /// The bank or cash account (a money account's name).
  final String account;

  /// Where it goes in the books: an account name from the chart of
  /// accounts. Ignored when [splits] is not empty.
  final String category;
  final String? customerId;
  final String? invoiceId;

  /// Set when this is a payment of a bill.
  final String? billId;

  /// Set when this expense was recorded from a receipt photo.
  final String? receiptId;

  /// When set, the amount is divided across several categories. The split
  /// amounts always add up to [amount].
  final List<TransactionSplit> splits;
  final List<String> tagIds;
  final String notes;

  /// Ticked off against a bank statement. Reconciled transactions are
  /// locked against changes that would move the balance.
  final bool reconciled;

  bool get isIncome => type == TransactionType.income;
  bool get isSplit => splits.isNotEmpty;

  /// Created by an invoice payment, bill payment or receipt: its money side
  /// is managed there.
  bool get isLinked => invoiceId != null || billId != null || receiptId != null;

  /// "Rent", or "Split (3)".
  String get categoryLabel => isSplit ? 'Split (${splits.length})' : category;

  /// (category, amount) pairs this transaction posts to.
  List<(String, double)> get allocations => isSplit
      ? [for (final s in splits) (s.category, s.amount)]
      : [(category, amount)];

  /// Money received that is a sale and has no invoice yet.
  bool get isInvoiceable =>
      isIncome &&
      invoiceId == null &&
      !isSplit &&
      !Constants.nonSalesIncomeCategories.contains(category);

  BankTransaction linkTo({required String invoiceId, String? customerId}) =>
      copyWith(invoiceId: invoiceId, customerId: this.customerId ?? customerId);

  BankTransaction copyWith({
    DateTime? date,
    String? description,
    double? amount,
    TransactionType? type,
    String? account,
    String? category,
    String? customerId,
    String? invoiceId,
    List<TransactionSplit>? splits,
    List<String>? tagIds,
    String? notes,
    bool? reconciled,
  }) =>
      BankTransaction(
        id: id,
        date: date ?? this.date,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        account: account ?? this.account,
        category: category ?? this.category,
        customerId: customerId ?? this.customerId,
        invoiceId: invoiceId ?? this.invoiceId,
        billId: billId,
        receiptId: receiptId,
        splits: splits ?? this.splits,
        tagIds: tagIds ?? this.tagIds,
        notes: notes ?? this.notes,
        reconciled: reconciled ?? this.reconciled,
      );

  /// Sum of the split amounts (equals [amount] for a valid split).
  double get splitTotal => round2(splits.fold<double>(0, (s, p) => s + p.amount));

  @override
  List<Object?> get props => [
        id,
        date,
        description,
        amount,
        type,
        account,
        category,
        customerId,
        invoiceId,
        billId,
        receiptId,
        splits,
        tagIds,
        notes,
        reconciled,
      ];
}
