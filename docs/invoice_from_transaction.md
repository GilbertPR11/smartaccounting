# Invoice from transaction

## Why
Wave-style apps usually go **invoice → payment → transaction**. Small businesses often get paid first: a cash sale, a DuitNow transfer, a cheque. This feature runs the other way: it starts from money already received and produces the invoice for the record.

## Rules (enforced in `InvoiceRepository.createInvoice`)
- Only **income** transactions with **no linked invoice** qualify.
- Categories in `Constants.nonSalesIncomeCategories` (Owner Investment, Loan, Transfer) are never invoiceable, because they aren't sales.
- One transaction → at most one invoice. A second attempt throws `AppException`.
- On save, the transaction amount is applied as a payment, **capped at the invoice total**:
  - total == amount → **Paid**
  - total > amount → **Partial**, with the remainder still due
  - total < amount → **Paid**, and the excess is shown as *unapplied* on the invoice
- The transaction gets `invoiceId` (and `customerId`, if it had none).

## Form behaviour (`pages/sales/invoice/invoice_form_page.dart`)
- Pre-fills customer, issue date (= payment date), terms *On receipt*, one line at the transaction amount, and a "payment received" note.
- The reconciliation box compares the invoice total with the transaction amount. **"Adjust prices to match (tax-inclusive)"** rescales line prices so the total *including tax* equals the amount received. Example: RM 1,296 received with 8% SST gives RM 1,200 + RM 96.

## Layout
- Phone: picker → form → invoice (the picker is replaced on save).
- 900px and wider: picker list on the left, form on the right. Selecting a different payment swaps the form.

## Not done yet
- Editing or voiding an invoice, and unlinking a transaction.
- Splitting one transaction across several invoices.
- LHDN MyInvois e-invoice fields and submission.
