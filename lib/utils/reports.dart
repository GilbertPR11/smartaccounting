import '../models/account_model.dart';
import '../models/bill_model.dart';
import '../models/invoice_model.dart';
import '../models/journal_model.dart';
import 'format.dart';
import 'ledger.dart';

// Financial reports as pure functions over a [Ledger] (accrual basis).
// Amounts are shown in each account's natural direction, so income and
// liabilities are positive numbers, like on a printed report.

/// One account and its amount on a report.
class ReportRow {
  const ReportRow(this.account, this.amount);

  final Account account;
  final double amount;
}

double _sum(Iterable<ReportRow> rows) => round2(rows.fold<double>(0, (s, r) => s + r.amount));

List<ReportRow> _rows(Ledger ledger, AccountType type, Map<String, double> net) {
  final rows = <ReportRow>[];
  for (final a in ledger.accounts.where((a) => a.type == type)) {
    final n = net[a.id] ?? 0;
    final amount = type.debitNormal ? n : round2(-n);
    if (amount.abs() > 0.004) rows.add(ReportRow(a, amount));
  }
  rows.sort((a, b) => a.account.code.compareTo(b.account.code));
  return rows;
}

// ------------------------------------------------------------ profit & loss

class ProfitAndLoss {
  const ProfitAndLoss({required this.from, required this.to, required this.income, required this.expenses});

  final DateTime from;
  final DateTime to;
  final List<ReportRow> income;
  final List<ReportRow> expenses;

  double get totalIncome => _sum(income);
  double get totalExpenses => _sum(expenses);
  double get netProfit => round2(totalIncome - totalExpenses);
}

ProfitAndLoss profitAndLoss(Ledger ledger, DateTime from, DateTime to) {
  final net = ledger.netByAccount(from: from, to: to);
  return ProfitAndLoss(
    from: dateOnly(from),
    to: dateOnly(to),
    income: _rows(ledger, AccountType.income, net),
    expenses: _rows(ledger, AccountType.expense, net),
  );
}

// ------------------------------------------------------------ balance sheet

class BalanceSheet {
  const BalanceSheet({
    required this.asOf,
    required this.assets,
    required this.liabilities,
    required this.equity,
    required this.profitToDate,
  });

  final DateTime asOf;
  final List<ReportRow> assets;
  final List<ReportRow> liabilities;
  final List<ReportRow> equity;

  /// All profit ever made up to [asOf] (retained earnings + this year).
  final double profitToDate;

  double get totalAssets => _sum(assets);
  double get totalLiabilities => _sum(liabilities);
  double get totalEquity => round2(_sum(equity) + profitToDate);
  double get totalLiabilitiesAndEquity => round2(totalLiabilities + totalEquity);

  /// Always true when the ledger is balanced. A test checks it.
  bool get balances => (totalAssets - totalLiabilitiesAndEquity).abs() < 0.01;
}

BalanceSheet balanceSheet(Ledger ledger, DateTime asOf) {
  final net = ledger.netByAccount(to: asOf);
  final income = _sum(_rows(ledger, AccountType.income, net));
  final expenses = _sum(_rows(ledger, AccountType.expense, net));
  return BalanceSheet(
    asOf: dateOnly(asOf),
    assets: _rows(ledger, AccountType.asset, net),
    liabilities: _rows(ledger, AccountType.liability, net),
    equity: _rows(ledger, AccountType.equity, net),
    profitToDate: round2(income - expenses),
  );
}

// ------------------------------------------------------------ trial balance

class TrialBalanceRow {
  const TrialBalanceRow(this.account, this.debit, this.credit);

  final Account account;
  final double debit;
  final double credit;
}

class TrialBalance {
  const TrialBalance(this.asOf, this.rows);

  final DateTime asOf;
  final List<TrialBalanceRow> rows;

  double get totalDebit => round2(rows.fold<double>(0, (s, r) => s + r.debit));
  double get totalCredit => round2(rows.fold<double>(0, (s, r) => s + r.credit));
}

TrialBalance trialBalance(Ledger ledger, DateTime asOf) {
  final net = ledger.netByAccount(to: asOf);
  final rows = <TrialBalanceRow>[];
  final accounts = [...ledger.accounts]..sort((a, b) => a.code.compareTo(b.code));
  for (final a in accounts) {
    final n = net[a.id] ?? 0;
    if (n.abs() < 0.005) continue;
    rows.add(TrialBalanceRow(a, n > 0 ? n : 0, n < 0 ? round2(-n) : 0));
  }
  return TrialBalance(dateOnly(asOf), rows);
}

// ------------------------------------------------------------ general ledger

class LedgerLine {
  const LedgerLine({
    required this.entry,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  final JournalEntry entry;
  final double debit;
  final double credit;

  /// Running balance in the account's natural direction.
  final double balance;
}

class AccountActivity {
  const AccountActivity({
    required this.account,
    required this.from,
    required this.to,
    required this.opening,
    required this.lines,
  });

  final Account account;
  final DateTime from;
  final DateTime to;
  final double opening;
  final List<LedgerLine> lines;

  double get closing => lines.isEmpty ? opening : lines.last.balance;
}

/// Every entry touching [account] in the period, with a running balance.
AccountActivity accountActivity(Ledger ledger, Account account, DateTime from, DateTime to) {
  final start = dateOnly(from);
  final end = dateOnly(to);
  final sign = account.type.debitNormal ? 1 : -1;
  var balance = 0.0;
  final lines = <LedgerLine>[];
  for (final e in ledger.entries) {
    if (e.date.isAfter(end)) break;
    for (final l in e.lines.where((l) => l.accountId == account.id)) {
      balance = round2(balance + sign * l.net);
      if (!e.date.isBefore(start)) {
        lines.add(LedgerLine(entry: e, debit: l.debit, credit: l.credit, balance: balance));
      }
    }
  }
  final moved = lines.fold<double>(0, (s, l) => s + sign * (l.debit - l.credit));
  return AccountActivity(
    account: account,
    from: start,
    to: end,
    opening: round2(balance - moved),
    lines: lines,
  );
}

// ------------------------------------------------------------ aging

const agingBuckets = ['Not yet due', '1–30 days', '31–60 days', '61–90 days', 'Over 90 days'];

int _bucket(DateTime due, DateTime today) {
  final late = dateOnly(today).difference(dateOnly(due)).inDays;
  if (late <= 0) return 0;
  if (late <= 30) return 1;
  if (late <= 60) return 2;
  if (late <= 90) return 3;
  return 4;
}

class AgingRow {
  AgingRow(this.partyId) : amounts = List<double>.filled(agingBuckets.length, 0);

  /// Customer or vendor id.
  final String partyId;
  final List<double> amounts;

  double get total => round2(amounts.fold<double>(0, (s, a) => s + a));
}

class AgingReport {
  const AgingReport(this.asOf, this.rows);

  final DateTime asOf;

  /// Biggest balance first.
  final List<AgingRow> rows;

  List<double> get columnTotals => [
        for (var i = 0; i < agingBuckets.length; i++)
          round2(rows.fold<double>(0, (s, r) => s + r.amounts[i])),
      ];

  double get total => round2(rows.fold<double>(0, (s, r) => s + r.total));
}

AgingReport _aging(Iterable<(String, DateTime, double)> open, DateTime today) {
  final byParty = <String, AgingRow>{};
  for (final (party, due, balance) in open) {
    if (balance <= 0.004) continue;
    final row = byParty.putIfAbsent(party, () => AgingRow(party));
    final b = _bucket(due, today);
    row.amounts[b] = round2(row.amounts[b] + balance);
  }
  final rows = byParty.values.toList()..sort((a, b) => b.total.compareTo(a.total));
  return AgingReport(dateOnly(today), rows);
}

/// What customers owe, by how late it is.
AgingReport agedReceivables(List<Invoice> invoices, DateTime today) =>
    _aging(invoices.map((i) => (i.customerId, i.dueDate, i.balance)), today);

/// What you owe vendors, by how late it is.
AgingReport agedPayables(List<Bill> bills, DateTime today) =>
    _aging(bills.map((b) => (b.vendorId, b.dueDate, b.balance)), today);

// ------------------------------------------------------------ SST

class TaxRow {
  const TaxRow(this.label, this.taxable, this.tax);

  final String label;

  /// Amount the tax was charged on.
  final double taxable;
  final double tax;
}

class SstReport {
  const SstReport({required this.from, required this.to, required this.charged, required this.paid});

  final DateTime from;
  final DateTime to;

  /// Charged to customers on invoices issued in the period (what you owe
  /// the tax authority).
  final List<TaxRow> charged;

  /// Paid to vendors on bills dated in the period (part of your costs;
  /// shown for reference).
  final List<TaxRow> paid;

  double get totalCharged => round2(charged.fold<double>(0, (s, r) => s + r.tax));
  double get totalPaid => round2(paid.fold<double>(0, (s, r) => s + r.tax));
}

SstReport sstReport(List<Invoice> invoices, List<Bill> bills, DateTime from, DateTime to) {
  final start = dateOnly(from);
  final end = dateOnly(to);
  bool inPeriod(DateTime d) => !dateOnly(d).isBefore(start) && !dateOnly(d).isAfter(end);

  List<TaxRow> group(Iterable<(String, double, double)> items) {
    final taxable = <String, double>{};
    final tax = <String, double>{};
    for (final (label, base, amount) in items) {
      taxable[label] = round2((taxable[label] ?? 0) + base);
      tax[label] = round2((tax[label] ?? 0) + amount);
    }
    return [for (final k in taxable.keys) TaxRow(k, taxable[k]!, tax[k]!)];
  }

  return SstReport(
    from: start,
    to: end,
    charged: group([
      for (final inv in invoices.where((i) => inPeriod(i.issueDate)))
        for (final l in inv.lines)
          if (l.tax != null && l.taxAmount > 0) (l.tax!.label, l.subtotal, l.taxAmount),
    ]),
    paid: group([
      for (final b in bills.where((b) => inPeriod(b.issueDate)))
        for (final l in b.lines)
          if (l.tax != null && l.taxAmount > 0) (l.tax!.label, l.amount, l.taxAmount),
    ]),
  );
}
