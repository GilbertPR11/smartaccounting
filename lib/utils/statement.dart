import '../models/invoice_model.dart';
import '../models/transaction_model.dart';
import 'format.dart';

// Customer statements, as pure functions over invoices and transactions
// (same idea as ledger_summary.dart: no widgets, no I/O, easy to test).
//
// Two kinds, like Wave:
// * Outstanding: every unpaid invoice today, with how late each one is.
// * Activity: everything in a period: the balance brought forward,
//   each invoice (+) and payment (−), and a running balance.

enum StatementEntryKind { invoice, payment }

class StatementEntry {
  const StatementEntry({
    required this.date,
    required this.kind,
    required this.reference,
    required this.description,
    required this.amount,
    required this.balance,
    required this.invoiceId,
  });

  final DateTime date;
  final StatementEntryKind kind;

  /// Invoice number (for payments, the invoice they paid).
  final String reference;
  final String description;

  /// Always positive; [kind] says whether it adds to or reduces the balance.
  final double amount;

  /// Running balance after this entry.
  final double balance;
  final String invoiceId;

  bool get isInvoice => kind == StatementEntryKind.invoice;
}

class ActivityStatement {
  const ActivityStatement({
    required this.from,
    required this.to,
    required this.opening,
    required this.entries,
  });

  final DateTime from;
  final DateTime to;

  /// What the customer owed at the start of [from].
  final double opening;
  final List<StatementEntry> entries;

  double get invoiced => round2(entries
      .where((e) => e.isInvoice)
      .fold<double>(0, (s, e) => s + e.amount));

  double get paid => round2(entries
      .where((e) => !e.isInvoice)
      .fold<double>(0, (s, e) => s + e.amount));

  /// What the customer owed at the end of [to].
  double get closing => round2(opening + invoiced - paid);
}

class OutstandingItem {
  const OutstandingItem(this.invoice, this.daysOverdue);

  final Invoice invoice;

  /// 0 when not yet due.
  final int daysOverdue;
}

class OutstandingStatement {
  const OutstandingStatement({required this.asOf, required this.items});

  final DateTime asOf;

  /// Oldest due date first.
  final List<OutstandingItem> items;

  double get total => round2(items.fold<double>(0, (s, i) => s + i.invoice.balance));

  /// Balance by lateness, in display order.
  Map<String, double> get aging {
    final buckets = {
      'Not yet due': 0.0,
      '1–30 days': 0.0,
      '31–60 days': 0.0,
      '61–90 days': 0.0,
      'Over 90 days': 0.0,
    };
    for (final i in items) {
      final d = i.daysOverdue;
      final key = d <= 0
          ? 'Not yet due'
          : d <= 30
              ? '1–30 days'
              : d <= 60
                  ? '31–60 days'
                  : d <= 90
                      ? '61–90 days'
                      : 'Over 90 days';
      buckets[key] = round2(buckets[key]! + i.invoice.balance);
    }
    return buckets;
  }
}

class Statements {
  Statements._();

  /// Payments applied to [inv], as (date, amount). A payment the invoice was
  /// created from counts only up to the invoice total; the excess was never
  /// applied to it.
  static List<(DateTime, double)> paymentsFor(Invoice inv, List<BankTransaction> txns) => [
        for (final t in txns)
          if (t.isIncome && t.invoiceId == inv.id)
            (
              dateOnly(t.date),
              t.id == inv.sourceTransactionId
                  ? round2(t.amount < inv.total ? t.amount : inv.total)
                  : t.amount,
            ),
      ];

  static ActivityStatement activity({
    required String customerId,
    required List<Invoice> invoices,
    required List<BankTransaction> transactions,
    required DateTime from,
    required DateTime to,
  }) {
    final start = dateOnly(from);
    final end = dateOnly(to);
    var opening = 0.0;
    final raw = <(DateTime, StatementEntryKind, Invoice, double)>[];

    for (final inv in invoices.where((i) => i.customerId == customerId)) {
      final issued = dateOnly(inv.issueDate);
      if (issued.isBefore(start)) {
        opening += inv.total;
      } else if (!issued.isAfter(end)) {
        raw.add((issued, StatementEntryKind.invoice, inv, inv.total));
      }
      for (final (date, amount) in paymentsFor(inv, transactions)) {
        if (date.isBefore(start)) {
          opening -= amount;
        } else if (!date.isAfter(end)) {
          raw.add((date, StatementEntryKind.payment, inv, amount));
        }
      }
    }

    // By date; on the same day the invoice comes before its payment.
    raw.sort((a, b) {
      final byDate = a.$1.compareTo(b.$1);
      return byDate != 0 ? byDate : a.$2.index.compareTo(b.$2.index);
    });

    var balance = round2(opening);
    final entries = <StatementEntry>[];
    for (final (date, kind, inv, amount) in raw) {
      final isInvoice = kind == StatementEntryKind.invoice;
      balance = round2(isInvoice ? balance + amount : balance - amount);
      entries.add(StatementEntry(
        date: date,
        kind: kind,
        reference: inv.number,
        description: !isInvoice
            ? 'Payment received, thank you'
            : inv.dueDate == inv.issueDate
                ? 'Invoice, due on receipt'
                : 'Invoice, due ${fmtDate(inv.dueDate)}',
        amount: amount,
        balance: balance,
        invoiceId: inv.id,
      ));
    }
    return ActivityStatement(from: start, to: end, opening: round2(opening), entries: entries);
  }

  static int _daysLate(Invoice inv, DateTime today) {
    final days = today.difference(dateOnly(inv.dueDate)).inDays;
    return days < 0 ? 0 : days;
  }

  static OutstandingStatement outstanding({
    required String customerId,
    required List<Invoice> invoices,
    required DateTime asOf,
  }) {
    final today = dateOnly(asOf);
    final items = [
      for (final inv in invoices)
        if (inv.customerId == customerId && inv.balance > 0.004)
          OutstandingItem(inv, _daysLate(inv, today)),
    ]..sort((a, b) => a.invoice.dueDate.compareTo(b.invoice.dueDate));
    return OutstandingStatement(asOf: today, items: items);
  }
}
