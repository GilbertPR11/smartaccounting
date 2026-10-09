import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartaccounting/app.dart';
import 'package:smartaccounting/components/statement_document.dart';
import 'package:smartaccounting/databases/local_db.dart';
import 'package:smartaccounting/exception/app_exception.dart';
import 'package:smartaccounting/models/estimate_model.dart';
import 'package:smartaccounting/models/invoice_model.dart';
import 'package:smartaccounting/models/recurring_invoice_model.dart';
import 'package:smartaccounting/pages/sales/invoice/invoice_detail_page.dart';
import 'package:smartaccounting/repository/estimate_repository.dart';
import 'package:smartaccounting/repository/invoice_repository.dart';
import 'package:smartaccounting/repository/recurring_repository.dart';
import 'package:smartaccounting/utils/format.dart';
import 'package:smartaccounting/utils/statement.dart';

void main() {
  final today = DateTime(2026, 10, 8);
  late LocalDb db;
  late InvoiceRepository invoices;
  late EstimateRepository estimates;
  late RecurringRepository recurring;

  const job = InvoiceLine(description: 'Job', unitPrice: 1000);

  setUp(() {
    db = LocalDb(today: today);
    invoices = InvoiceRepository(db);
    estimates = EstimateRepository(db);
    recurring = RecurringRepository(db, invoices);
  });

  String someCustomer() => db.customers.keys.first;

  group('Estimates', () {
    Future<Estimate> newEstimate({String number = 'Q-1'}) => estimates.createEstimate(
          customerId: someCustomer(),
          number: number,
          issueDate: today,
          expiryDate: today.add(const Duration(days: 30)),
          lines: const [job],
        );

    test('status follows the answer and the expiry date', () async {
      final e = await newEstimate();
      expect(e.statusOn(today), EstimateStatus.pending);
      expect(e.statusOn(today.add(const Duration(days: 31))), EstimateStatus.expired);

      await estimates.setDecision(e.id, EstimateDecision.accepted);
      expect(db.estimates[e.id]!.statusOn(today), EstimateStatus.accepted);
      // Accepted stays accepted after expiry: it still waits to be invoiced.
      expect(db.estimates[e.id]!.statusOn(today.add(const Duration(days: 90))),
          EstimateStatus.accepted);
    });

    test('numbers are unique and expiry cannot precede the date', () async {
      await newEstimate(number: 'Q-1');
      expect(() => newEstimate(number: 'q-1'), throwsA(isA<AppException>()));
      expect(
        () => estimates.createEstimate(
            customerId: someCustomer(),
            number: 'Q-2',
            issueDate: today,
            expiryDate: today.subtract(const Duration(days: 1)),
            lines: const [job]),
        throwsA(isA<AppException>()),
      );
    });

    test('converting creates the invoice and locks the estimate', () async {
      final e = await newEstimate();
      final inv = await invoices.createInvoice(
        customerId: e.customerId,
        issueDate: today,
        dueDate: today.add(const Duration(days: 30)),
        lines: e.lines,
        estimateId: e.id,
      );
      expect(inv.estimateId, e.id);
      expect(inv.number, startsWith('INV-'));
      expect(db.estimates[e.id]!.invoiceId, inv.id);
      expect(db.estimates[e.id]!.statusOn(today), EstimateStatus.converted);

      // Not twice, and no more edits.
      expect(
        () => invoices.createInvoice(
            customerId: e.customerId,
            issueDate: today,
            dueDate: today,
            lines: e.lines,
            estimateId: e.id),
        throwsA(isA<AppException>()),
      );
      expect(() => estimates.setDecision(e.id, null), throwsA(isA<AppException>()));
      expect(() => estimates.deleteEstimate(e.id), throwsA(isA<AppException>()));
    });

    test('changing the items clears the customer\'s answer', () async {
      final e = await newEstimate();
      await estimates.setDecision(e.id, EstimateDecision.accepted);
      final edited = await estimates.updateEstimate(
        id: e.id,
        customerId: e.customerId,
        issueDate: e.issueDate,
        expiryDate: e.expiryDate,
        lines: const [InvoiceLine(description: 'Bigger job', unitPrice: 2000)],
      );
      expect(edited.decision, isNull);
    });
  });

  group('Recurring invoices', () {
    test('occurrences keep the day and clamp to the month end', () {
      final r = RecurringInvoice(
        id: 'x',
        customerId: 'c',
        lines: const [job],
        frequency: RecurFrequency.monthly,
        startDate: DateTime(2028, 1, 31),
      );
      expect(r.occurrence(1), DateTime(2028, 2, 29)); // leap year
      expect(r.occurrence(2), DateTime(2028, 3, 31)); // no drift to the 29th
      expect(addMonths(DateTime(2026, 11, 30), 3), DateTime(2027, 2, 28));
    });

    test('a back-dated schedule catches up, each invoice on its own date', () async {
      final before = db.invoices.length;
      final r = await recurring.createSchedule(
        customerId: someCustomer(),
        lines: const [job],
        frequency: RecurFrequency.monthly,
        startDate: DateTime(2026, 8, 8),
        termsDays: 14,
      );
      final issued = db.invoices.values.where((i) => i.recurringId == r.id).toList()
        ..sort((a, b) => a.issueDate.compareTo(b.issueDate));
      expect(db.invoices.length, before + 3);
      expect(issued.map((i) => i.issueDate),
          [DateTime(2026, 8, 8), DateTime(2026, 9, 8), DateTime(2026, 10, 8)]);
      expect(issued.first.dueDate, DateTime(2026, 8, 22));
      expect(r.issuedCount, 3);
      expect(r.nextDate, DateTime(2026, 11, 8));

      // Running again issues nothing new.
      expect(await recurring.issueDue(), isEmpty);
    });

    test('stops after the set number of invoices', () async {
      final r = await recurring.createSchedule(
        customerId: someCustomer(),
        lines: const [job],
        frequency: RecurFrequency.monthly,
        startDate: DateTime(2026, 6, 1),
        maxCount: 2,
      );
      expect(r.issuedCount, 2);
      expect(r.status, RecurringStatus.ended);
      expect(r.nextDate, isNull);
    });

    test('resuming skips the dates missed while paused', () async {
      final r = RecurringInvoice(
        id: 'paused1',
        customerId: someCustomer(),
        lines: const [job],
        frequency: RecurFrequency.weekly,
        startDate: today.subtract(const Duration(days: 21)),
        paused: true,
      );
      db.recurring[r.id] = r;
      expect(await recurring.issueDue(), isEmpty); // paused: nothing

      await recurring.setPaused(r.id, false);
      final issued = db.invoices.values.where((i) => i.recurringId == r.id).toList();
      expect(issued.length, 1); // only today's, nothing back-dated
      expect(issued.single.issueDate, today);
    });

    test('rhythm is fixed once invoices exist', () async {
      final r = await recurring.createSchedule(
        customerId: someCustomer(),
        lines: const [job],
        frequency: RecurFrequency.monthly,
        startDate: today,
      );
      expect(r.issuedCount, 1);
      expect(
        () => recurring.updateSchedule(
            id: r.id,
            customerId: r.customerId,
            lines: r.lines,
            frequency: RecurFrequency.weekly,
            startDate: r.startDate),
        throwsA(isA<AppException>()),
      );
    });

    test('seeded schedules are not due on start-up', () async {
      expect(await recurring.issueDue(), isEmpty);
    });
  });

  group('Statements', () {
    test('activity closing balance equals what the customer owes', () {
      for (final c in db.customers.values) {
        final all = db.invoices.values.toList();
        final s = Statements.activity(
          customerId: c.id,
          invoices: all,
          transactions: db.transactions.values.toList(),
          from: DateTime(2026, 9, 1),
          to: today,
        );
        final owed = round2(all
            .where((i) => i.customerId == c.id)
            .fold<double>(0, (sum, i) => sum + i.balance));
        expect(s.closing, owed, reason: c.name);
        if (s.entries.isNotEmpty) expect(s.entries.last.balance, s.closing);
      }
    });

    test('outstanding lists unpaid invoices and ages them', () {
      final siti = db.customers.values.firstWhere((c) => c.name.startsWith('Siti'));
      final s = Statements.outstanding(
          customerId: siti.id, invoices: db.invoices.values.toList(), asOf: today);
      expect(s.items, isNotEmpty);
      expect(s.items.every((i) => i.invoice.balance > 0), isTrue);
      // Siti's seeded invoice was due 10 days ago.
      expect(s.aging['1–30 days'], greaterThan(0));
      expect(s.aging.values.fold<double>(0, (a, b) => a + b), closeTo(s.total, 0.001));
    });
  });

  group('Screens', () {
    Future<void> pumpPhone(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(SmartAccountingApp(db: LocalDb(today: today)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sales'));
      await tester.pumpAndSettle();
    }

    testWidgets('estimate → convert → invoice', (tester) async {
      await pumpPhone(tester);
      await tester.scrollUntilVisible(find.text('Estimates'), 200);
      await tester.tap(find.text('Estimates'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siti Design Studio'));
      await tester.pumpAndSettle();
      expect(find.text('Convert to invoice'), findsOneWidget);

      await tester.tap(find.text('Convert to invoice'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Invoice from EST-'), findsOneWidget);

      await tester.tap(find.text('Save invoice'));
      await tester.pumpAndSettle();
      expect(find.byType(InvoiceDetailPage), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('Converted from EST-'), 300);
      expect(find.textContaining('Converted from EST-'), findsOneWidget);
    });

    testWidgets('customer page → statement', (tester) async {
      await pumpPhone(tester);
      await tester.scrollUntilVisible(find.text('Customers'), 200);
      await tester.tap(find.text('Customers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kopi Kita Café'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Statement'));
      await tester.pumpAndSettle();
      expect(find.byType(StatementDocument), findsOneWidget);
    });
  });
}
