import 'dart:math' as math;

import '../models/bill_model.dart';
import '../models/invoice_model.dart';
import '../models/transaction_model.dart';
import 'format.dart';

/// Pure dashboard calculations over Bloc state. No widgets, no I/O,
/// so they are trivial to unit-test.
class LedgerSummary {
  LedgerSummary._();

  static double cashBalance(double opening, List<BankTransaction> txns) =>
      round2(txns.fold<double>(
          opening, (s, t) => t.isIncome ? s + t.amount : s - t.amount));

  static double receivable(List<Invoice> invoices) =>
      round2(invoices.fold<double>(0, (s, i) => s + math.max(0, i.balance)));

  static List<Invoice> overdue(List<Invoice> invoices, DateTime today) =>
      invoices.where((i) => i.statusOn(today) == InvoiceStatus.overdue).toList();

  static double sumBalance(List<Invoice> invoices) =>
      round2(invoices.fold<double>(0, (s, i) => s + i.balance));

  /// (month start, money in, money out) for the last [count] months, oldest first.
  static List<(DateTime, double, double)> monthly(
      List<BankTransaction> txns, DateTime today, int count) {
    final result = <(DateTime, double, double)>[];
    for (var k = count - 1; k >= 0; k--) {
      final start = DateTime(today.year, today.month - k, 1);
      final end = DateTime(start.year, start.month + 1, 1);
      double inc = 0, exp = 0;
      for (final t in txns) {
        if (t.date.isBefore(start) || !t.date.isBefore(end)) continue;
        if (t.isIncome) {
          inc += t.amount;
        } else {
          exp += t.amount;
        }
      }
      result.add((start, round2(inc), round2(exp)));
    }
    return result;
  }

  /// End-of-day cash balance for each of the last [days] days, oldest first.
  static List<double> balanceSeries(
      double opening, List<BankTransaction> txns, DateTime today, int days) {
    final start = dateOnly(today).subtract(Duration(days: days - 1));
    var balance = opening;
    // Everything before the window collapses into the starting balance.
    final byDay = <int, double>{};
    for (final t in txns) {
      final delta = t.isIncome ? t.amount : -t.amount;
      final d = dateOnly(t.date);
      if (d.isBefore(start)) {
        balance += delta;
      } else {
        final idx = d.difference(start).inDays;
        byDay[idx] = (byDay[idx] ?? 0) + delta;
      }
    }
    final series = <double>[];
    for (var i = 0; i < days; i++) {
      balance += byDay[i] ?? 0;
      series.add(round2(balance));
    }
    return series;
  }

  /// Money in minus money out since the 1st of [today]'s month.
  static double netThisMonth(List<BankTransaction> txns, DateTime today) {
    final start = DateTime(today.year, today.month, 1);
    return round2(txns
        .where((t) => !t.date.isBefore(start))
        .fold<double>(0, (s, t) => t.isIncome ? s + t.amount : s - t.amount));
  }

  /// What you still owe vendors.
  static double payable(List<Bill> bills) =>
      round2(bills.fold<double>(0, (s, b) => s + math.max(0, b.balance)));

  /// Unpaid bills that are overdue or due within [days].
  static List<Bill> billsDueSoon(List<Bill> bills, DateTime today, {int days = 7}) {
    final limit = dateOnly(today).add(Duration(days: days));
    return bills
        .where((b) => b.balance > 0.004 && !dateOnly(b.dueDate).isAfter(limit))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }
}
