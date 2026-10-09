import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartaccounting/app.dart';
import 'package:smartaccounting/databases/local_db.dart';
import 'package:smartaccounting/exception/app_exception.dart';
import 'package:smartaccounting/models/account_model.dart';
import 'package:smartaccounting/models/journal_model.dart';
import 'package:smartaccounting/models/transaction_model.dart';
import 'package:smartaccounting/pages/accounting/reports/balance_sheet_page.dart';
import 'package:smartaccounting/pages/home/widgets/side_menu.dart';
import 'package:smartaccounting/repository/account_repository.dart';
import 'package:smartaccounting/repository/journal_repository.dart';
import 'package:smartaccounting/repository/product_repository.dart';
import 'package:smartaccounting/repository/reconciliation_repository.dart';
import 'package:smartaccounting/repository/transaction_repository.dart';
import 'package:smartaccounting/utils/csv_import.dart';
import 'package:smartaccounting/utils/format.dart';
import 'package:smartaccounting/utils/ledger.dart';
import 'package:smartaccounting/utils/ledger_summary.dart';
import 'package:smartaccounting/utils/reports.dart';

void main() {
  final today = DateTime(2026, 10, 8);
  late LocalDb db;

  setUp(() => db = LocalDb(today: today));

  Ledger ledger() => Ledger.build(
        accounts: db.chart.values.toList(),
        invoices: db.invoices.values.toList(),
        bills: db.bills.values.toList(),
        transactions: db.transactions.values.toList(),
        journals: db.journals.values.toList(),
        openingBalance: db.openingBalance,
        openingAccountId: db.openingAccountId,
      );

  Account role(AccountRole r) => db.chart.values.firstWhere((a) => a.role == r);
  Account named(String name) => db.chart.values.firstWhere((a) => a.name == name);

  group('Ledger', () {
    test('every derived entry balances, and so does the trial balance', () {
      final l = ledger();
      expect(l.entries, isNotEmpty);
      expect(l.entries.every((e) => e.isBalanced), isTrue);
      final tb = trialBalance(l, today);
      expect(tb.totalDebit, closeTo(tb.totalCredit, 0.001));
    });

    test('balance sheet balances', () {
      final bs = balanceSheet(ledger(), today);
      expect(bs.balances, isTrue,
          reason: 'assets ${bs.totalAssets} vs L+E ${bs.totalLiabilitiesAndEquity}');
    });

    test('bank accounts agree with the cash balance on the dashboard', () {
      final l = ledger();
      final bank = db.chart.values
          .where((a) => a.isMoney)
          .fold<double>(0, (s, a) => s + l.balanceOf(a, to: today));
      final cash = LedgerSummary.cashBalance(db.openingBalance, db.transactions.values.toList());
      expect(round2(bank), cash);
    });

    test('receivable, payable and SST match the invoices and bills', () {
      final l = ledger();
      final invoices = db.invoices.values.toList();
      expect(l.balanceOf(role(AccountRole.receivable), to: today),
          closeTo(LedgerSummary.receivable(invoices), 0.001));
      expect(l.balanceOf(role(AccountRole.payable), to: today),
          closeTo(LedgerSummary.payable(db.bills.values.toList()), 0.001));
      expect(l.balanceOf(role(AccountRole.salesTax), to: today),
          closeTo(invoices.fold<double>(0, (s, i) => s + i.taxTotal), 0.001));
    });

    test('the seeded journal moves Software and Owner Investment', () {
      final activity = accountActivity(ledger(), named('Owner Investment'), DateTime(2026, 1, 1), today);
      expect(activity.lines.any((l) => l.entry.source == JournalSource.manual), isTrue);
    });
  });

  group('Transactions', () {
    late TransactionRepository repo;
    setUp(() => repo = TransactionRepository(db));

    test('a split posts to each category', () async {
      final t = await repo.createTransaction(
        type: TransactionType.expense,
        date: today,
        description: 'Stationery and lunch',
        amount: 150,
        account: 'Maybank Current',
        splits: const [
          TransactionSplit(category: 'Office Supplies', amount: 100),
          TransactionSplit(category: 'Meals & Entertainment', amount: 50),
        ],
      );
      final entry = ledger().entries.firstWhere((e) => e.sourceId == t.id);
      expect(entry.lines.length, 3);
      expect(entry.isBalanced, isTrue);
    });

    test('split parts must add up to the amount', () {
      expect(
        () => repo.createTransaction(
          type: TransactionType.expense,
          date: today,
          description: 'x',
          amount: 150,
          account: 'Maybank Current',
          splits: const [
            TransactionSplit(category: 'Office Supplies', amount: 100),
            TransactionSplit(category: 'Travel', amount: 10),
          ],
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('deleting a bill payment takes it off the bill', () async {
      final payment = db.transactions.values.firstWhere((t) => t.billId != null);
      final before = db.bills[payment.billId]!.amountPaid;
      await repo.deleteTransaction(payment.id);
      expect(db.bills[payment.billId]!.amountPaid, round2(before - payment.amount));
    });

    test('a linked payment keeps its amount when edited', () async {
      final payment = db.transactions.values.firstWhere((t) => t.billId != null);
      final saved = await repo.updateTransaction(
        id: payment.id,
        type: payment.type,
        date: payment.date,
        description: 'Renamed',
        amount: 1,
        account: payment.account,
      );
      expect(saved.description, 'Renamed');
      expect(saved.amount, payment.amount);
    });
  });

  group('Chart of accounts', () {
    late AccountRepository repo;
    setUp(() => repo = AccountRepository(db));

    test('renaming an account renames every reference to it', () async {
      final rent = named('Rent');
      await repo.updateAccount(id: rent.id, name: 'Office Rent', code: rent.code);
      expect(db.transactions.values.any((t) => t.category == 'Rent'), isFalse);
      expect(db.transactions.values.any((t) => t.category == 'Office Rent'), isTrue);
      expect(db.bills.values.expand((b) => b.lines).any((l) => l.category == 'Rent'), isFalse);
      expect(db.vendors.values.any((v) => v.defaultCategory == 'Office Rent'), isTrue);
      // Still balanced, still the same rent expense.
      expect(trialBalance(ledger(), today).totalDebit,
          closeTo(trialBalance(ledger(), today).totalCredit, 0.001));
    });

    test('names are unique and system accounts can\'t be archived', () async {
      expect(() => repo.addAccount(name: 'rent', type: AccountType.expense),
          throwsA(isA<AppException>()));
      expect(() => repo.setArchived(role(AccountRole.receivable).id, true),
          throwsA(isA<AppException>()));
    });
  });

  group('Journal entries', () {
    test('must balance', () {
      final repo = JournalRepository(db);
      expect(
        () => repo.createJournal(date: today, description: 'Bad', lines: [
          JournalLine(accountId: named('Rent').id, debit: 100),
          JournalLine(accountId: named('Owner Investment').id, credit: 90),
        ]),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('Reconciliation', () {
    late ReconciliationRepository repo;
    setUp(() => repo = ReconciliationRepository(db));

    test('finishes only when the difference is zero, then locks transactions', () async {
      const account = 'Maybank Current';
      final ids = [for (final t in db.transactions.values) if (t.account == account) t.id];
      final expected = round2(db.openingBalance +
          db.transactions.values
              .where((t) => t.account == account)
              .fold<double>(0, (s, t) => s + (t.isIncome ? t.amount : -t.amount)));

      expect(
        () => repo.complete(
            account: account, statementDate: today, endingBalance: expected + 1, transactionIds: ids),
        throwsA(isA<AppException>()),
      );
      final r = await repo.complete(
          account: account, statementDate: today, endingBalance: expected, transactionIds: ids);
      expect(db.transactions[ids.first]!.reconciled, isTrue);
      expect(repo.beginningBalance(account), expected);
      expect(() => TransactionRepository(db).deleteTransaction(ids.first),
          throwsA(isA<AppException>()));

      await repo.undo(r.id);
      expect(db.transactions[ids.first]!.reconciled, isFalse);
    });
  });

  group('Statement import', () {
    test('reads debit/credit columns and Malaysian dates', () {
      final result = parseStatementCsv(
        'Transaction Date,Description,Debit Amount,Credit Amount\n'
        '01/10/2026,"IBG CREDIT TAN, HARDWARE",,"2,700.00"\n'
        '03-Oct-2026,SERVICE CHARGE,8.00,\n'
        '31/02/2026,BAD DATE,1.00,\n',
      );
      expect(result.lines.length, 2);
      expect(result.lines.first.description, 'IBG CREDIT TAN, HARDWARE');
      expect(result.lines.first.amount, 2700);
      expect(result.lines[1].amount, -8);
      expect(result.lines[1].date, DateTime(2026, 10, 3));
      expect(result.problems.single, contains('Row 4'));
    });

    test('reads a signed amount column and DR/CR suffixes', () {
      expect(parseStatementAmount('(45.00)'), -45);
      expect(parseStatementAmount('RM 1,234.50 DR'), -1234.5);
      expect(parseStatementAmount('12.00 CR'), 12);
      final result = parseStatementCsv('2026-10-05,Coffee,-12.40\n2026-10-06,Refund,5');
      expect(result.lines.map((l) => l.amount), [-12.4, 5]);
    });

    test('imported rows land as uncategorized', () async {
      final repo = TransactionRepository(db);
      await repo.importStatement('Maybank Current', [
        StatementLine(date: today, description: 'Bank fee', amount: -8),
      ]);
      final t = db.transactions.values.firstWhere((t) => t.description == 'Bank fee');
      expect(t.category, role(AccountRole.uncategorizedExpense).name);
    });
  });

  group('Products', () {
    test('something you buy needs an expense category', () {
      final repo = ProductRepository(db);
      expect(
        () => repo.addProduct(name: 'Toner', price: 0, sold: false, bought: true),
        throwsA(isA<AppException>()),
      );
    });
  });

  testWidgets('desktop: Accounting menu opens the balance sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SmartAccountingApp(db: LocalDb(today: today)));
    await tester.pumpAndSettle();

    final inMenu = find.byType(SideMenuPanel);
    await tester.tap(find.descendant(of: inMenu, matching: find.text('Accounting')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: inMenu, matching: find.text('Reports')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balance sheet'));
    await tester.pumpAndSettle();

    expect(find.byType(BalanceSheetPage), findsOneWidget);
    expect(find.text('Out of balance'), findsNothing);
  });
}
