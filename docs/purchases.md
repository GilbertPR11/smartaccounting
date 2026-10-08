# Purchases: bills, receipts, vendors

## The split (so nothing is counted twice)
| | Bill | Receipt |
|---|---|---|
| Means | Money you **owe** a vendor, paid later | Proof of money you **already spent** |
| Creates money out | Only when you **Pay** it (each payment = one transaction) | When you **Record expense** |
| Status | Unpaid / Partial / Paid / Overdue | To review / Recorded / Attached to bill |

A receipt can instead be **attached to a bill** ("Create a bill instead"). That keeps the photo as proof and creates no transaction, because the bill's payment does that. This is the only way a receipt and a bill should meet.

## Rules (enforced in the repositories)
- **Bills** (`BillRepository`):
  - Needs a vendor, at least one line, and amounts above zero.
  - The due date can't be before the bill date.
  - The same vendor reference can't be entered twice.
  - Payments are capped at the balance. Each payment creates an expense transaction with `billId`, categorised by the bill's largest line.
- **Receipts** (`ReceiptRepository`):
  - Recording needs an amount, date, category and paid-from account. It creates an expense transaction with `receiptId`.
  - Only "To review" receipts can be edited or deleted. Recorded ones are kept as proof.
- **Vendors** (`VendorRepository`): names must be unique. A vendor's usual category pre-fills new bill lines.

## Where things show up
- **Purchases tab:** what you owe, what you've spent this month, a "To do" list (bills due within 7 days or overdue, receipts to review), and spending by category.
- **Dashboard → Needs attention:** the next two bills due, and receipts to review.
- **Accounting:** bill payments and recorded receipts appear as money out. Tapping one opens its bill or receipt.

## Photos
`image_picker`, downscaled on pick (1600 px, 80% quality). The camera is offered on phones only; desktop and web choose a file. Photos live in memory until local storage (sqflite) lands. Store them as files with a path in the database then, not as blobs.

## Not done yet
- **OCR** (reading amount, date and merchant from the photo). Needs on-device text recognition, such as `google_mlkit_text_recognition`, which is Android/iOS only.
- **Editing or voiding a bill**, and undoing a payment.
- **Recurring bills** (rent, subscriptions).
- **Purchase tax** (SST paid) reporting.
