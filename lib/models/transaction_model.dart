import 'package:equatable/equatable.dart';

import '../config/constants.dart';

enum TransactionType { income, expense }

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
  });

  final String id;
  final DateTime date;
  final String description;

  /// Always positive; the sign comes from [type].
  final double amount;
  final TransactionType type;
  final String account;
  final String category;
  final String? customerId;
  final String? invoiceId;

  /// Set when this is a payment of a bill.
  final String? billId;

  /// Set when this expense was recorded from a receipt photo.
  final String? receiptId;

  bool get isIncome => type == TransactionType.income;

  /// Money received that is a sale and has no invoice yet.
  bool get isInvoiceable =>
      isIncome &&
      invoiceId == null &&
      !Constants.nonSalesIncomeCategories.contains(category);

  BankTransaction linkTo({required String invoiceId, String? customerId}) =>
      BankTransaction(
        id: id,
        date: date,
        description: description,
        amount: amount,
        type: type,
        account: account,
        category: category,
        customerId: this.customerId ?? customerId,
        invoiceId: invoiceId,
        billId: billId,
        receiptId: receiptId,
      );

  @override
  List<Object?> get props =>
      [id, date, description, amount, type, account, category, customerId, invoiceId, billId, receiptId];
}
