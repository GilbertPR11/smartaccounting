import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartaccounting/app.dart';
import 'package:smartaccounting/databases/local_db.dart';
import 'package:smartaccounting/pages/sales/invoice/invoice_detail_page.dart';

void main() {
  final today = DateTime(2026, 10, 7);

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SmartAccountingApp(db: LocalDb(today: today)));
    await tester.pumpAndSettle();
  }

  testWidgets('phone: dashboard → Sales hub', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Cash across 2 accounts'), findsOneWidget);

    await tester.tap(find.text('Sales'));
    await tester.pumpAndSettle();
    expect(find.text('Sales & payments'), findsOneWidget);
    expect(find.text('Invoice from a payment'), findsOneWidget);
  });

  testWidgets('phone: pick a transaction → pre-filled invoice form', (tester) async {
    await pumpAt(tester, const Size(400, 900));
    await tester.tap(find.text('Sales'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invoice from a payment'));
    await tester.pumpAndSettle();
    expect(find.text('Select a transaction'), findsOneWidget);

    await tester.tap(find.text('Cash sale – walk-in customer'));
    await tester.pumpAndSettle();
    expect(find.text('Invoice from transaction'), findsOneWidget); // form title
    expect(find.text('Choose a customer'), findsOneWidget);
    expect(find.text('RM 350.00'), findsWidgets);
  });

  testWidgets('tablet: compact navigation rail', (tester) async {
    await pumpAt(tester, const Size(820, 1180));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('desktop: sidebar stays, invoices open side by side', (tester) async {
    await pumpAt(tester, const Size(1440, 900));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);

    await tester.tap(find.text('Sales'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invoices'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(InvoiceDetailPage), findsOneWidget);
  });
}
