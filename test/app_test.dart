import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartaccounting/app.dart';
import 'package:smartaccounting/databases/local_db.dart';
import 'package:smartaccounting/pages/home/widgets/side_menu.dart';
import 'package:smartaccounting/pages/sales/customer/customer_page.dart';
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

  testWidgets('tablet: sidebar starts hidden, ☰ opens it', (tester) async {
    await pumpAt(tester, const Size(820, 1180));
    expect(find.byType(SideMenuRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byTooltip('Show menu'));
    await tester.pumpAndSettle();
    expect(find.byType(SideMenuPanel), findsOneWidget);

    await tester.tap(find.byTooltip('Hide menu'));
    await tester.pumpAndSettle();
    expect(find.byType(SideMenuRail), findsOneWidget);
  });

  testWidgets('phone: ☰ drawer opens a page inside a category', (tester) async {
    await pumpAt(tester, const Size(400, 900));
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    final inMenu = find.byType(SideMenuPanel);
    await tester.tap(find.descendant(of: inMenu, matching: find.text('Sales & payments')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: inMenu, matching: find.text('Customers')));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerPage), findsOneWidget);
  });

  testWidgets('desktop: sidebar dropdown opens invoices side by side', (tester) async {
    await pumpAt(tester, const Size(1440, 900));
    final inMenu = find.byType(SideMenuPanel);
    expect(inMenu, findsOneWidget);

    await tester.tap(find.descendant(of: inMenu, matching: find.text('Sales & payments')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: inMenu, matching: find.text('Invoices')));
    await tester.pumpAndSettle();

    expect(find.byType(SideMenuPanel), findsOneWidget); // sidebar stays
    expect(find.byType(InvoiceDetailPage), findsOneWidget);
  });
}
