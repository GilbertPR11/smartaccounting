# Accounting: ledger, chart of accounts, reports, reconciliation

## The ledger is derived, not stored
`utils/ledger.dart` turns the app's records into double-entry journal entries every time a report or balance is needed (**accrual basis**). Only **manual journal entries** are stored. So a report can never disagree with the invoices, bills and transactions behind it, and there's no "posting" step that could fail halfway.

**For the backend:** the server should store real journal entries, written in the same database transaction as the document. The rules below are the spec.

| Record | Debit | Credit |
|---|---|---|
| Opening cash | first bank account (by code) | Opening Balance Equity |
| Invoice | Accounts Receivable: total | Sales: subtotal; SST Payable: tax |
| Payment of an invoice | bank account | Accounts Receivable: applied amount; Customer Prepayments: any excess |
| Bill | each line's expense account (tax included: purchase SST isn't claimable) | Accounts Payable |
| Payment of a bill | Accounts Payable | bank account |
| Other money in | bank account | its category (or each split part) |
| Other money out | its category (or each split part) | bank account |
| Journal entry | as entered | as entered |

Tests check the sums: every entry balances, the trial balance balances, the balance sheet balances, bank balances equal the dashboard cash, and Receivable, Payable and SST equal the open invoices, open bills and tax charged.

## Chart of accounts (`AccountRepository`)
- **Five types:** asset, liability, equity, income, expense.
- **Bank and cash accounts** are assets marked "money". They are what transactions are paid from and into, and what the "Paid from" pickers list.
- **System accounts** (lock icon): Receivable, Payable, SST Payable, Customer Prepayments, Opening Balance Equity, Sales, and the two Uncategorized accounts.
  - The app posts to these automatically and finds them by role, not by name.
  - They can be renamed but not archived.
- **Categories are account names.** Transactions, bill lines, receipts and vendors store the category as an account name. So:
  - names are unique;
  - **renaming** an account rewrites every reference in the same write;
  - category pickers list accounts from the chart, so accounts users add appear everywhere.
- **Archiving** hides an account from pickers but keeps its history in reports.
- **An account's type can't change**, because its history was posted on that side of the books.

## Transactions (`TransactionRepository`)
- **Add** money in or out, with a category or a **split** across several. Split parts must add up to the amount.
- **Tags** (e.g. a branch or a project) are free labels for filtering. They don't affect the books.
- **Linked transactions** (invoice payments, bill payments, receipt expenses) only take a new description, notes and tags here. Their money side belongs to the invoice, bill or receipt.
- **Deleting** a payment takes it off its invoice or bill.
- **Can't be deleted:**
  - the payment an invoice was created from;
  - expenses from receipts;
  - reconciled transactions.
- **Uncategorized:** money with no real category goes to "Uncategorized income/expense". The Accounting page counts these so they get fixed.

## Journal entries (`JournalRepository`)
For adjustments where no money moves: depreciation, corrections, an expense the owner paid personally. They need at least two lines, each a debit or a credit, and debits must equal credits.

## Reports (`utils/reports.dart`, pure functions)
- **Profit & loss:** for a period; income and expense accounts.
- **Balance sheet:** as of a date. Equity includes "Profit to date" (retained earnings), so no year-end closing entry is needed.
- **Trial balance:** debit and credit balance of every account.
- **Account transactions (general ledger):** one account, with a running balance. Tapping a line opens the invoice, bill, transaction or journal entry behind it.
- **Aged receivables and payables:** by customer or vendor; buckets are not yet due, 1–30, 31–60, 61–90 and over 90 days.
- **SST summary:**
  - SST charged on invoices dated in the period (what you owe);
  - SST paid on bills (shown for reference, since it's part of costs).
  - Check the SST-02 figures with a tax agent.

Export (PDF/CSV) waits for the backend.

## Reconciliation (`ReconciliationRepository`)
1. Enter the statement's end date and closing balance.
2. Tick the transactions that appear on it.
3. Finish when the difference is zero.

Rules:
- Each reconciliation starts from the previous one's closing balance. The first one starts from the opening balance for the first bank account, and from zero for others.
- Reconciled transactions are **locked**: date, amount and account can't change, and they can't be deleted. Only the **latest** reconciliation of an account can be undone, so the chain of starting balances stays right.

## Statement import (`utils/csv_import.dart`)
Paste a CSV export; the importer handles:
- **Columns:** a header row in any order, or no header (then date, description, amount).
- **Amounts:** a signed Amount column, or separate Debit/Credit, Withdrawal/Deposit or Money out/Money in columns. Formats like `1,234.50`, `RM 12`, `(45.00)` and `45.00 DR`.
- **Dates:** day-first (`31/10/2026`), ISO (`2026-10-31`), and `31 Oct 2026`.

Rows that match an existing transaction (same account, date, amount and direction) are flagged and left unticked. Imported rows land as Uncategorized for review.

**Next:** a file picker (and OFX/QIF) can feed the same parser.

## Not built yet
- **Cash-basis reports.** Everything is accrual.
- **Transfers between bank accounts** as one entry. For now, record money out of one account and money in to the other, both with the category "Transfer Clearing". It nets to zero.
- **Bank feeds.** Malaysian banks rarely offer them; import is the practical path.
- **Multi-currency, budgets, fixed-asset depreciation schedules.**
- **Period locking** ("books closed up to …").
