# Invoice design

Sales & Payments → **Invoice design**, or **Customize design** on any invoice.

## What users can change
| Area | Options |
|---|---|
| Look | Layout (Classic / Modern / Compact), accent colour (9 presets), document title (INVOICE, TAX INVOICE, RECEIPT…) |
| Logo | Upload PNG/JPG (resized to ≤ 800 px on pick), size S/M/L, show/hide |
| Business details | Name, address, email, phone, SSM registration no., SST registration no. |
| Show / hide | Business address, contact, reg. no., SST no.; customer address, customer email, due date; qty & unit-price columns, tax rate per line, tax breakdown, amount paid & due; notes, payment instructions, footer |
| Text | Payment instructions, footer |

Edits are a draft with a live preview. Nothing changes on real invoices until **Save**. Leaving with unsaved changes asks first. **Reset design** restores layout, colour and toggles, and keeps the logo and texts.

## How it's built
- `models/invoice_template_model.dart`: plain data with no Flutter types (colour is an ARGB int), so it can go into sqflite or an API unchanged.
- `models/business_profile_model.dart`: who the invoice is from.
- `repository/setting_repository.dart` → `bloc/setting/` (smartpos: `Bloc/setting`).
- `components/invoice_document.dart`: **the only invoice renderer.** The invoice page and the designer preview both use it, so the preview can't drift from the real thing.
- One design per business. Saved designs apply to all invoices, including old ones (see below).

## Decisions and limits
- **Presets, not a free-form designer.** Drag-and-drop layouts are expensive to build and easy to break (overlapping fields, missing tax lines). Presets plus switches cover what Wave, Xero and QuickBooks users actually change.
- **Tax is always shown.** Turning off "Tax breakdown" collapses it into one "Tax" line; it never hides tax.
- **Design applies retroactively.** Old invoices re-render with the current design. Once invoices are sent as PDFs, store a snapshot (or the PDF) at send time so the customer's copy never changes.
- **The logo lives in memory** like all other data until local storage (sqflite) is added.
- **No PDF yet.** `InvoiceDocument` is a Flutter widget. PDF export will need the `pdf` package (smartpos uses 3.11.3) and a second renderer driven by the same `InvoiceTemplate`. Expect small visual differences unless both are tested side by side.
