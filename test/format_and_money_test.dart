import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartaccounting/app.dart';
import 'package:smartaccounting/components/money_text.dart';
import 'package:smartaccounting/databases/local_db.dart';
import 'package:smartaccounting/theme/theme.dart';
import 'package:smartaccounting/utils/format.dart';
import 'package:smartaccounting/utils/ledger_summary.dart';

void main() {
  final today = DateTime(2026, 10, 8);

  test('relativeDue reads like a person would say it', () {
    expect(relativeDue(today, today), 'Due today');
    expect(relativeDue(today.add(const Duration(days: 1)), today), 'Due tomorrow');
    expect(relativeDue(today.add(const Duration(days: 5)), today), 'Due in 5 days');
    expect(relativeDue(today.subtract(const Duration(days: 1)), today), '1 day overdue');
    expect(relativeDue(today.subtract(const Duration(days: 12)), today), '12 days overdue');
  });

  test('initialsOf', () {
    expect(initialsOf('Tan Hardware Sdn Bhd'), 'TH');
    expect(initialsOf('kopi'), 'K');
    expect(initialsOf('Lim & Co Logistics'), 'LC');
    expect(initialsOf(''), '?');
  });

  test('balance series ends at the current cash balance', () {
    final db = LocalDb(today: today);
    final txns = db.transactions.values.toList();
    final series = LedgerSummary.balanceSeries(db.openingBalance, txns, today, 90);
    expect(series.length, 90);
    expect(series.last, LedgerSummary.cashBalance(db.openingBalance, txns));
  });

  testWidgets('MoneyText reads as one amount', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(
        body: Column(children: [
          MoneyText(15240.5),
          MoneyText(-2500),
          MoneyText(1296, showSign: true),
        ]),
      ),
    ));
    expect(find.text('RM 15,240.50'), findsOneWidget);
    expect(find.text('−RM 2,500.00'), findsOneWidget);
    expect(find.text('+RM 1,296.00'), findsOneWidget);
  });

  for (final size in const [Size(390, 844), Size(1440, 900)]) {
    testWidgets('whole app renders in dark mode at ${size.width.toInt()} px', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(SmartAccountingApp(db: LocalDb(today: today)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Cash across 2 accounts'), findsOneWidget);
    });
  }
}
