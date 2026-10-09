import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartaccounting/app.dart';
import 'package:smartaccounting/databases/local_db.dart';
import 'package:smartaccounting/exception/app_exception.dart';
import 'package:smartaccounting/models/bill_model.dart';
import 'package:smartaccounting/models/invoice_model.dart';
import 'package:smartaccounting/models/receipt_model.dart';
import 'package:smartaccounting/models/transaction_model.dart';
import 'package:smartaccounting/pages/home/widgets/side_menu.dart';
import 'package:smartaccounting/pages/purchases/bill/bill_detail_page.dart';
import 'package:smartaccounting/repository/bill_repository.dart';
import 'package:smartaccounting/repository/receipt_repository.dart';
import 'package:smartaccounting/repository/vendor_repository.dart';

void main() {
  final today = DateTime(2026, 10, 8);
  late LocalDb db;
  late BillRepository bills;
  late ReceiptRepository receipts;
  late VendorRepository vendors;

  // Any non-empty bytes will do for repository tests (nothing decodes them).
  final fakePhoto = Uint8List.fromList(List.filled(32, 7));

  setUp(() {
    db = LocalDb(today: today);
    bills = BillRepository(db);
    receipts = ReceiptRepository(db);
    vendors = VendorRepository(db);
  });

  group('Bills', () {
    test('paying part of a bill records money out and marks it partial', () async {
      final v = db.vendors.values.first;
      final bill = await bills.createBill(
        vendorId: v.id,
        number: 'T-1',
        issueDate: today,
        dueDate: today.add(const Duration(days: 30)),
        lines: const [BillLine(description: 'Test', category: 'Other', amount: 1000)],
      );
      await bills.recordPayment(
          billId: bill.id, amount: 300, date: today, account: 'Maybank Current');

      final updated = db.bills[bill.id]!;
      expect(updated.amountPaid, 300);
      expect(updated.statusOn(today), InvoiceStatus.partial);
      final payment = db.transactions.values.singleWhere((t) => t.billId == bill.id);
      expect(payment.type, TransactionType.expense);
      expect(payment.amount, 300);
    });

    test('payment is capped at what is still owed', () async {
      final bill = db.bills.values.firstWhere((b) => b.balance > 0);
      await bills.recordPayment(
          billId: bill.id, amount: bill.balance + 999, date: today, account: 'Cash on Hand');
      expect(db.bills[bill.id]!.balance, 0);
      expect(db.bills[bill.id]!.statusOn(today), InvoiceStatus.paid);
    });

    test('the same vendor reference cannot be entered twice', () async {
      final existing = db.bills.values.firstWhere((b) => b.number.isNotEmpty);
      expect(
        () => bills.createBill(
          vendorId: existing.vendorId,
          number: existing.number.toLowerCase(),
          issueDate: today,
          dueDate: today,
          lines: const [BillLine(description: 'Dup', category: 'Other', amount: 1)],
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('due date cannot be before the bill date', () async {
      expect(
        () => bills.createBill(
          vendorId: db.vendors.keys.first,
          number: '',
          issueDate: today,
          dueDate: today.subtract(const Duration(days: 1)),
          lines: const [BillLine(description: 'x', category: 'Other', amount: 1)],
        ),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('Receipts', () {
    test('a new receipt waits in To review', () async {
      final r = await receipts.addReceipt(fakePhoto);
      expect(r.status, ReceiptStatus.toReview);
      expect((await receipts.fetchReceipts()).first.id, r.id);
    });

    test('recording a receipt creates one money-out transaction', () async {
      final r = await receipts.addReceipt(fakePhoto);
      final before = db.transactions.length;
      await receipts.recordAsExpense(r.copyWith(
        merchant: 'Petronas',
        date: today,
        amount: 85.40,
        category: 'Travel',
        account: 'Cash on Hand',
      ));
      expect(db.transactions.length, before + 1);
      final t = db.transactions.values.singleWhere((t) => t.receiptId == r.id);
      expect(t.amount, 85.40);
      expect(t.description, 'Petronas');
      expect(db.receipts[r.id]!.status, ReceiptStatus.recorded);
    });

    test('recording needs an amount', () async {
      final r = await receipts.addReceipt(fakePhoto);
      expect(
        () => receipts.recordAsExpense(
            r.copyWith(date: today, category: 'Travel', account: 'Cash on Hand')),
        throwsA(isA<AppException>()),
      );
    });

    test('attaching a receipt to a bill does not create a second expense', () async {
      final r = await receipts.addReceipt(fakePhoto);
      final before = db.transactions.length;
      final bill = await bills.createBill(
        vendorId: db.vendors.keys.first,
        number: 'FROM-RECEIPT',
        issueDate: today,
        dueDate: today.add(const Duration(days: 14)),
        lines: const [BillLine(description: 'Parts', category: 'Repairs & Maintenance', amount: 120)],
        receiptId: r.id,
      );
      expect(db.transactions.length, before);
      expect(db.receipts[r.id]!.status, ReceiptStatus.attached);
      expect(db.receipts[r.id]!.billId, bill.id);
    });

    test('recorded receipts cannot be deleted', () async {
      final r = await receipts.addReceipt(fakePhoto);
      await receipts.recordAsExpense(r.copyWith(
          date: today, amount: 10, category: 'Meals & Entertainment', account: 'Cash on Hand'));
      expect(() => receipts.deleteReceipt(r.id), throwsA(isA<AppException>()));
    });
  });

  test('vendor names must be unique', () async {
    final name = db.vendors.values.first.name;
    expect(() => vendors.addVendor(name: name.toUpperCase()), throwsA(isA<AppException>()));
  });

  group('Screens', () {
    Future<void> pumpAt(WidgetTester tester, Size size) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(SmartAccountingApp(db: LocalDb(today: today)));
      await tester.pumpAndSettle();
    }

    testWidgets('phone: Purchases shows what you owe and opens Bills', (tester) async {
      await pumpAt(tester, const Size(390, 844));
      await tester.tap(find.text('Purchases'));
      await tester.pumpAndSettle();
      expect(find.text('You owe vendors'), findsOneWidget);

      await tester.tap(find.text('Bills'));
      await tester.pumpAndSettle();
      expect(find.text('Kedai Cetak Jaya'), findsOneWidget); // overdue printing bill
    });

    testWidgets('desktop: bills open side by side', (tester) async {
      await pumpAt(tester, const Size(1440, 900));
      final inMenu = find.byType(SideMenuPanel);
      await tester.tap(find.descendant(of: inMenu, matching: find.text('Purchases')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: inMenu, matching: find.text('Bills')));
      await tester.pumpAndSettle();
      expect(find.byType(BillDetailPage), findsOneWidget);
      expect(find.byType(SideMenuPanel), findsOneWidget); // sidebar stays
    });
  });
}
