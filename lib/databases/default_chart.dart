import '../config/constants.dart';
import '../models/account_model.dart';
import 'local_db.dart';

/// The chart of accounts every new business starts with. Small on purpose
/// (Wave-style): users add accounts as they need them.
class DefaultChart {
  DefaultChart._();

  static void apply(LocalDb db) {
    Account add(String code, String name, AccountType type,
        {bool money = false, AccountRole? role, String description = ''}) {
      final a = Account(
        id: db.newId('a'),
        code: code,
        name: name,
        type: type,
        isMoney: money,
        role: role,
        description: description,
      );
      db.chart[a.id] = a;
      return a;
    }

    // Assets.
    db.openingAccountId = add('1000', 'Maybank Current', AccountType.asset,
            money: true, description: 'Main business bank account')
        .id;
    add('1010', 'Cash on Hand', AccountType.asset, money: true);
    add('1100', 'Transfer Clearing', AccountType.asset,
        description: 'Use as the category on both sides of a move between your own '
            'accounts; it nets to zero');
    add('1200', 'Accounts Receivable', AccountType.asset,
        role: AccountRole.receivable, description: 'What customers owe you on invoices');

    // Liabilities.
    add('2000', 'Accounts Payable', AccountType.liability,
        role: AccountRole.payable, description: 'What you owe vendors on bills');
    add('2100', 'SST Payable', AccountType.liability,
        role: AccountRole.salesTax, description: 'Sales and service tax charged to customers');
    add('2200', 'Customer Prepayments', AccountType.liability,
        role: AccountRole.customerPrepayments,
        description: 'Money received that isn\'t applied to an invoice yet');
    add('2300', 'Loans', AccountType.liability);

    // Equity.
    add('3000', 'Owner Investment', AccountType.equity);
    add('3100', 'Owner Drawings', AccountType.equity);
    add('3900', 'Opening Balance Equity', AccountType.equity,
        role: AccountRole.openingBalance,
        description: 'Balances you had before you started using the app');

    // Income.
    add('4000', 'Sales', AccountType.income, role: AccountRole.sales);
    add('4100', 'Other Income', AccountType.income);
    add('4900', 'Uncategorized Income', AccountType.income,
        role: AccountRole.uncategorizedIncome);

    // Expenses.
    var code = 5000;
    for (final name in Constants.expenseCategories) {
      add('$code', name, AccountType.expense);
      code += 10;
    }
    add('5800', 'Bank Fees', AccountType.expense);
    add('5900', 'Uncategorized Expense', AccountType.expense,
        role: AccountRole.uncategorizedExpense);
  }
}
