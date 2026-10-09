import 'package:equatable/equatable.dart';

/// The five kinds of account in double-entry bookkeeping.
enum AccountType { asset, liability, equity, income, expense }

extension AccountTypeInfo on AccountType {
  String get label => switch (this) {
        AccountType.asset => 'Asset',
        AccountType.liability => 'Liability',
        AccountType.equity => 'Equity',
        AccountType.income => 'Income',
        AccountType.expense => 'Expense',
      };

  String get plural => switch (this) {
        AccountType.asset => 'Assets',
        AccountType.liability => 'Liabilities',
        AccountType.equity => 'Equity',
        AccountType.income => 'Income',
        AccountType.expense => 'Expenses',
      };

  /// Assets and expenses grow with debits; the rest grow with credits.
  bool get debitNormal => this == AccountType.asset || this == AccountType.expense;

  /// Income and expense accounts reset each period (they feed profit);
  /// the others carry their balance forward (they feed the balance sheet).
  bool get isProfitAndLoss => this == AccountType.income || this == AccountType.expense;
}

/// Accounts the bookkeeping rules post to automatically. The app finds them
/// by role, never by name, so users can rename them freely.
enum AccountRole {
  receivable,
  payable,
  salesTax,
  customerPrepayments,
  openingBalance,
  sales,
  uncategorizedIncome,
  uncategorizedExpense,
}

/// One account in the chart of accounts.
///
/// Bank and cash accounts ([isMoney]) are what transactions are paid from
/// and into. Categories on transactions, bills and receipts are account
/// names; renaming an account updates them everywhere (AccountRepository).
class Account extends Equatable {
  const Account({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.description = '',
    this.isMoney = false,
    this.role,
    this.archived = false,
  });

  final String id;

  /// Optional numbering, e.g. 1000 for the main bank account.
  final String code;
  final String name;
  final AccountType type;
  final String description;

  /// A bank or cash account (an asset that transactions move money in/out of).
  final bool isMoney;

  /// Set on accounts the app posts to automatically. They can be renamed
  /// but not archived.
  final AccountRole? role;
  final bool archived;

  bool get isSystem => role != null;

  /// "1000 · Maybank Current"
  String get display => code.isEmpty ? name : '$code · $name';

  Account copyWith({
    String? code,
    String? name,
    String? description,
    bool? archived,
  }) =>
      Account(
        id: id,
        code: code ?? this.code,
        name: name ?? this.name,
        type: type,
        description: description ?? this.description,
        isMoney: isMoney,
        role: role,
        archived: archived ?? this.archived,
      );

  @override
  List<Object?> get props => [id, code, name, type, description, isMoney, role, archived];
}
