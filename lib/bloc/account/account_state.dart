part of 'account_bloc.dart';

class AccountState extends Equatable {
  const AccountState({
    this.status = LoadStatus.initial,
    this.accounts = const [],
    this.error,
  });

  final LoadStatus status;

  /// Every account (archived too), by code.
  final List<Account> accounts;
  final String? error;

  List<Account> get active => accounts.where((a) => !a.archived).toList();

  Account? byId(String? id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  Account? byName(String? name) {
    final n = name?.trim().toLowerCase();
    for (final a in accounts) {
      if (a.name.toLowerCase() == n) return a;
    }
    return null;
  }

  List<Account> ofType(AccountType type) => active.where((a) => a.type == type).toList();

  /// Bank and cash accounts.
  List<Account> get money => active.where((a) => a.isMoney).toList();

  /// Names of active expense accounts, for category pickers.
  List<String> get expenseNames => [for (final a in ofType(AccountType.expense)) a.name];

  /// Where money coming in can go: income first, then liabilities (loans,
  /// prepayments) and equity (owner money).
  List<Account> get incomeCategories => [
        ...ofType(AccountType.income),
        ...ofType(AccountType.liability),
        ...ofType(AccountType.equity),
        ...active.where((a) => a.type == AccountType.asset && !a.isMoney),
      ];

  /// Where money going out can go: expenses first, then assets bought,
  /// liabilities paid down and owner drawings.
  List<Account> get expenseCategories => [
        ...ofType(AccountType.expense),
        ...active.where((a) => a.type == AccountType.asset && !a.isMoney),
        ...ofType(AccountType.liability),
        ...ofType(AccountType.equity),
      ];

  AccountState copyWith({LoadStatus? status, List<Account>? accounts, String? error}) =>
      AccountState(
        status: status ?? this.status,
        accounts: accounts ?? this.accounts,
        error: error,
      );

  @override
  List<Object?> get props => [status, accounts, error];
}
