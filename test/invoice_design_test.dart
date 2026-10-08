import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartaccounting/app.dart';
import 'package:smartaccounting/components/invoice_document.dart';
import 'package:smartaccounting/databases/local_db.dart';
import 'package:smartaccounting/exception/app_exception.dart';
import 'package:smartaccounting/models/business_profile_model.dart';
import 'package:smartaccounting/models/customer_model.dart';
import 'package:smartaccounting/models/invoice_model.dart';
import 'package:smartaccounting/models/invoice_template_model.dart';
import 'package:smartaccounting/repository/setting_repository.dart';

void main() {
  final today = DateTime(2026, 10, 7);

  const profile = BusinessProfile(
    name: 'Acme Sdn Bhd',
    address: '1 Jalan Test',
    sstNo: 'W10-TEST',
  );
  const customer = Customer(id: 'c1', name: 'Customer A', email: 'a@example.com');
  final invoice = Invoice(
    id: 'i1',
    number: 'INV-0042',
    customerId: 'c1',
    issueDate: today,
    dueDate: today.add(const Duration(days: 14)),
    lines: const [InvoiceLine(description: 'Widget', quantity: 2, unitPrice: 10)],
    notes: 'Hello notes',
    amountPaid: 5,
  );

  Future<void> pumpDoc(WidgetTester tester, InvoiceTemplate template) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: InvoiceDocument(
              invoice: invoice,
              customer: customer,
              profile: profile,
              template: template,
            ),
          ),
        ),
      ));

  testWidgets('toggles hide and show parts of the invoice', (tester) async {
    await pumpDoc(tester, const InvoiceTemplate());
    expect(find.text('SST reg. no. W10-TEST'), findsOneWidget);
    expect(find.text('QTY'), findsOneWidget);
    expect(find.text('Hello notes'), findsOneWidget);
    expect(find.text('Amount due'), findsOneWidget);
    expect(find.text('a@example.com'), findsNothing); // off by default

    await pumpDoc(
      tester,
      const InvoiceTemplate().copyWith(
        showSstNo: false,
        showQuantityColumns: false,
        showNotes: false,
        showAmountPaid: false,
        showCustomerEmail: true,
        title: 'TAX INVOICE',
      ),
    );
    expect(find.text('SST reg. no. W10-TEST'), findsNothing);
    expect(find.text('QTY'), findsNothing);
    expect(find.text('Hello notes'), findsNothing);
    expect(find.text('Amount due'), findsNothing);
    expect(find.text('a@example.com'), findsOneWidget);
    expect(find.text('TAX INVOICE'), findsOneWidget);
  });

  testWidgets('every layout renders without overflow on a phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final layout in InvoiceLayout.values) {
      await pumpDoc(tester, const InvoiceTemplate().copyWith(layout: layout));
      expect(tester.takeException(), isNull, reason: layout.name);
    }
  });

  test('logo version changes on upload/remove, not on other edits', () {
    const t = InvoiceTemplate();
    final withLogo = t.copyWith(logoBytes: Uint8List.fromList([1, 2, 3]));
    expect(withLogo.logoVersion, t.logoVersion + 1);
    expect(withLogo.copyWith(showFooter: false).logoVersion, withLogo.logoVersion);
    expect(withLogo.copyWith(clearLogo: true).hasLogo, isFalse);
  });

  test('repository rejects an empty business name', () async {
    final repo = SettingRepository(LocalDb(today: today));
    expect(
      () => repo.saveInvoiceSettings(
          profile: BusinessProfile.empty, template: const InvoiceTemplate()),
      throwsA(isA<AppException>()),
    );
  });

  testWidgets('desktop: design page shows editor and live preview', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SmartAccountingApp(db: LocalDb(today: today)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sales'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invoice design'));
    await tester.pumpAndSettle();

    expect(find.byType(InvoiceDocument), findsOneWidget);
    expect(find.text('INVOICE'), findsWidgets); // preview + title field

    await tester.enterText(find.widgetWithText(TextField, 'Document title'), 'RECEIPT');
    await tester.pump();
    expect(find.text('RECEIPT'), findsWidgets); // preview updated live
  });
}
