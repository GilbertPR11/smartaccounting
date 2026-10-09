import '../models/account_model.dart';
import '../models/bill_model.dart';
import '../models/invoice_model.dart';
import '../models/journal_model.dart';
import '../models/transaction_model.dart';
import 'format.dart';

/// The general ledger, derived from the app's records (accrual basis).
///
/// Nothing here is stored. Each call turns invoices, bills, bank
/// transactions and manual journal entries into balanced journal entries,
/// so reports can never disagree with the documents they come from.
/// The posting rules below are the spec for the backend later
/// (see docs/accounting.md).
///
/// | Record | Debit | Credit |
/// |---|---|---|
/// | Opening cash | first bank account | Opening Balance Equity |
/// | Invoice | Accounts Receivable (total) | Sales (subtotal), SST Payable (tax) |
/// | Payment of an invoice | bank account | Accounts Receivable (applied); Customer Prepayments (any excess) |
/// | Bill | each line's expense account (incl. tax) | Accounts Payable |
/// | Payment of a bill | Accounts Payable | bank account |
/// | Other money in | bank account | its category account(s) |
/// | Other money out | its category account(s) | bank account |
/// | Manual journal | as entered | as entered |
class Ledger {
  Ledger._(this.accounts, this.entries);

  /// Every account, archived ones included (old entries may use them).
  final List<Account> accounts;

  /// Oldest first.
  final List<JournalEntry> entries;

  Account? byId(String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  static Ledger build({
    required List<Account> accounts,
    required List<Invoice> invoices,
    required List<Bill> bills,
    required List<BankTransaction> transactions,
    required List<JournalEntry> journals,
    required double openingBalance,
    String? openingAccountId,
  }) {
    // Before the chart has loaded there's nothing to post to.
    if (accounts.isEmpty) return Ledger._(const [], const []);
    final byName = <String, Account>{};
    for (final a in accounts) {
      // Active accounts win over archived ones with the same name.
      final key = a.name.trim().toLowerCase();
      if (!byName.containsKey(key) || byName[key]!.archived) byName[key] = a;
    }
    Account? role(AccountRole r) {
      for (final a in accounts) {
        if (a.role == r) return a;
      }
      return null;
    }

    final uncatIncome = role(AccountRole.uncategorizedIncome);
    final uncatExpense = role(AccountRole.uncategorizedExpense);
    final ar = role(AccountRole.receivable)!.id;
    final ap = role(AccountRole.payable)!.id;
    final sst = role(AccountRole.salesTax)!.id;
    final prepay = role(AccountRole.customerPrepayments)!.id;
    final sales = role(AccountRole.sales)!.id;
    final openingEq = role(AccountRole.openingBalance)!.id;

    String accountFor(String name, {required bool income}) =>
        byName[name.trim().toLowerCase()]?.id ??
        (income ? uncatIncome : uncatExpense)!.id;

    final entries = <JournalEntry>[];
    void add(DateTime date, String description, List<JournalLine> lines,
        JournalSource source, String? sourceId, String id) {
      final kept = lines.where((l) => l.debit.abs() > 0.004 || l.credit.abs() > 0.004).toList();
      if (kept.isEmpty) return;
      entries.add(JournalEntry(
        id: id,
        date: dateOnly(date),
        description: description,
        lines: kept,
        source: source,
        sourceId: sourceId,
      ));
    }

    // Opening cash sits in the opening account (or the first money account),
    // dated before anything else.
    final moneyAccounts = accounts.where((a) => a.isMoney).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    final openingAccount = accounts.where((a) => a.id == openingAccountId).firstOrNull ??
        (moneyAccounts.isEmpty ? null : moneyAccounts.first);
    if (openingBalance != 0 && openingAccount != null) {
      final dates = <DateTime>[
        for (final i in invoices) i.issueDate,
        for (final b in bills) b.issueDate,
        for (final t in transactions) t.date,
        for (final j in journals) j.date,
      ];
      final first = dates.isEmpty
          ? DateTime(2000)
          : dates.reduce((a, b) => a.isBefore(b) ? a : b);
      final bank = openingAccount.id;
      final amt = round2(openingBalance);
      add(
        first.subtract(const Duration(days: 1)),
        'Opening balance',
        amt > 0
            ? [JournalLine(accountId: bank, debit: amt), JournalLine(accountId: openingEq, credit: amt)]
            : [JournalLine(accountId: openingEq, debit: -amt), JournalLine(accountId: bank, credit: -amt)],
        JournalSource.opening,
        null,
        'opening',
      );
    }

    // Invoices.
    final invoiceById = {for (final i in invoices) i.id: i};
    for (final inv in invoices) {
      add(
        inv.issueDate,
        'Invoice ${inv.number}',
        [
          JournalLine(accountId: ar, debit: inv.total),
          JournalLine(accountId: sales, credit: inv.subtotal),
          JournalLine(accountId: sst, credit: inv.taxTotal),
        ],
        JournalSource.invoice,
        inv.id,
        'inv-${inv.id}',
      );
    }

    // Bills: each line to its expense account, tax included (SST on
    // purchases can't be claimed back, so it's part of the cost).
    for (final bill in bills) {
      final debits = <String, double>{};
      for (final line in bill.lines) {
        final acc = accountFor(line.category, income: false);
        debits[acc] = round2((debits[acc] ?? 0) + line.total);
      }
      add(
        bill.issueDate,
        bill.number.isEmpty ? 'Bill' : 'Bill ${bill.number}',
        [
          for (final e in debits.entries) JournalLine(accountId: e.key, debit: e.value),
          JournalLine(accountId: ap, credit: bill.total),
        ],
        JournalSource.bill,
        bill.id,
        'bill-${bill.id}',
      );
    }

    // Bank and cash transactions.
    for (final t in transactions) {
      final bank = accountFor(t.account, income: t.isIncome);
      final inv = invoiceById[t.invoiceId];
      if (t.isIncome && inv != null) {
        // A payment of an invoice. The invoice's source transaction counts
        // only up to the invoice total; the rest is a prepayment.
        final applied = t.id == inv.sourceTransactionId
            ? round2(t.amount < inv.total ? t.amount : inv.total)
            : t.amount;
        add(
          t.date,
          t.description,
          [
            JournalLine(accountId: bank, debit: t.amount),
            JournalLine(accountId: ar, credit: applied),
            JournalLine(accountId: prepay, credit: round2(t.amount - applied)),
          ],
          JournalSource.invoicePayment,
          t.id,
          'txn-${t.id}',
        );
      } else if (!t.isIncome && t.billId != null) {
        add(
          t.date,
          t.description,
          [
            JournalLine(accountId: ap, debit: t.amount),
            JournalLine(accountId: bank, credit: t.amount),
          ],
          JournalSource.billPayment,
          t.id,
          'txn-${t.id}',
        );
      } else {
        final parts = <String, double>{};
        for (final (category, amount) in t.allocations) {
          final acc = accountFor(category, income: t.isIncome);
          parts[acc] = round2((parts[acc] ?? 0) + amount);
        }
        add(
          t.date,
          t.description,
          t.isIncome
              ? [
                  JournalLine(accountId: bank, debit: t.amount),
                  for (final e in parts.entries) JournalLine(accountId: e.key, credit: e.value),
                ]
              : [
                  for (final e in parts.entries) JournalLine(accountId: e.key, debit: e.value),
                  JournalLine(accountId: bank, credit: t.amount),
                ],
          JournalSource.transaction,
          t.id,
          'txn-${t.id}',
        );
      }
    }

    entries.addAll(journals);
    entries.sort((a, b) => a.date.compareTo(b.date));
    return Ledger._(List.unmodifiable(accounts), List.unmodifiable(entries));
  }

  /// Debit minus credit per account, for entries dated in [from]..[to]
  /// (both inclusive, either open-ended).
  Map<String, double> netByAccount({DateTime? from, DateTime? to}) {
    final start = from == null ? null : dateOnly(from);
    final end = to == null ? null : dateOnly(to);
    final result = <String, double>{};
    for (final e in entries) {
      if (start != null && e.date.isBefore(start)) continue;
      if (end != null && e.date.isAfter(end)) continue;
      for (final l in e.lines) {
        result[l.accountId] = (result[l.accountId] ?? 0) + l.net;
      }
    }
    return result.map((k, v) => MapEntry(k, round2(v)));
  }

  /// An account's balance in its natural direction (positive = normal):
  /// assets/expenses debit minus credit, the others credit minus debit.
  double balanceOf(Account account, {DateTime? from, DateTime? to}) {
    final net = netByAccount(from: from, to: to)[account.id] ?? 0;
    return account.type.debitNormal ? net : round2(-net);
  }
}
