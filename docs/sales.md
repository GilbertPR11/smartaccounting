# Sales & payments: estimates, recurring invoices, statements

Same sidebar as Wave: Estimates, Invoices, Recurring invoices, Customer statements, Customers, Products & services. Invoices are covered in `invoice_from_transaction.md` and `invoice_design.md`.

## Estimates (`EstimateRepository`)
A quote. It uses the same lines and design as an invoice, but **nothing is owed** until it's converted. It never touches transactions, "Owed to you" or statements.

| Status | When |
|---|---|
| Awaiting reply | No answer yet, still valid |
| Expired | No answer and past "valid until" |
| Accepted | Customer said yes. Stays accepted after expiry, because it's still waiting to be invoiced |
| Declined | Customer said no |
| Invoiced | Converted. Read-only from then on |

**Rules:**
- Numbers (EST-0001…) are unique.
- "Valid until" can't be before the date.
- Editing the customer or items clears the customer's answer, because they answered a different quote.

**Convert to invoice** opens the normal invoice form pre-filled, so prices and terms can still change. `InvoiceRepository.createInvoice(estimateId:)` creates the invoice and marks the estimate in the **same write**, so you can never have one without the other. The same estimate can't be converted twice.

## Recurring invoices (`RecurringRepository`)
A schedule: customer, items, frequency (weekly / monthly / every 3 months / yearly), first date, an optional end (a date or a number of invoices), and payment terms.

**No server, so no midnight job.** Invoices are issued by `issueDue()`, which runs:
- when the app starts (`LoadRecurring(catchUp: true)` in `app.dart`),
- when a schedule is saved or resumed.

It catches up on every date that has passed. Each invoice gets its own scheduled date, not today's date, and catch-up is capped at 24 per schedule per run.

**Rules:**
- Dates come from the start date: occurrence *n* = start + *n* periods, clamped to the month's last day. A schedule starting 31 Jan issues on 28/29 Feb, then 31 Mar, with no drift.
- Invoices are created through `InvoiceRepository`, so numbering and validation match hand-made invoices. Each one carries `recurringId`.
- Once a schedule has issued anything, its frequency and start date are locked. Change the items, terms or end freely; those apply to future invoices only.
- **Pausing** stops new invoices. **Resuming skips** the dates missed while paused and never back-dates them. The app asks before resuming.
- Deleting a schedule keeps the invoices it already issued.

**Limits of doing this on the device:**
- If nobody opens the app, invoices aren't issued. They appear on the next open, back-dated to their real dates.
- With several devices and a future sync, two devices could issue the same invoice. When a backend arrives, move `issueDue()` to the server and delete the start-up catch-up.

## Customer statements (`utils/statement.dart`, pure functions)
- **Outstanding:** every unpaid invoice today, how many days late it is, and an aging summary (not yet due, 1–30, 31–60, 61–90, over 90 days).
- **Activity:** for a period, the balance brought forward, each invoice (+) and payment (−) by date, and a running balance. The closing balance always equals what the customer owes. A test checks this for every seeded customer.

**Payment amounts:** a payment counts at the amount applied to the invoice. When an invoice was created from a bank transaction larger than the invoice, only the invoice total counts; the rest was never applied.

The statement is drawn with the invoice design (logo, colour, payment instructions). On phones the paper keeps its layout and is scaled to fit, like a PDF preview.

## Customer page
Tap a customer to open their page. It shows:
- what they owe and what's overdue;
- shortcuts for a new invoice, estimate, recurring invoice or statement (the customer is pre-filled);
- their invoices, estimates and schedules.

## Not done yet
- **PDF export and sending** (email/WhatsApp) for invoices, estimates and statements. The share buttons are placeholders.
- **Editing a customer.** There's no update method yet.
- **Deposits** on estimates.
- **Auto-sending** recurring invoices and **auto-charging** cards: these need a backend.
- **Statements as of a past date.** The outstanding statement is always as of today.
