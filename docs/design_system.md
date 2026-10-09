# Design system: "calm finance"

The app should feel like a well-kept ledger: quiet surfaces, one accent, numbers that line up.

## Tokens (`lib/theme/colors.dart`)
| Token | Light | Dark | Use |
|---|---|---|---|
| Mist | `#F3F6F4` | `#0F1714` | Page background |
| Paper | `#FFFFFF` | `#16201C` | Cards, sheets, inputs |
| Ink | `#16241F` | `#E6EDEA` | Primary text |
| Slate | `#5E6E68` | `#93A39D` | Secondary text, currency, cents |
| Hairline | `#DCE3DF` | `#26332E` | Borders and dividers (instead of shadows) |
| Ledger green | `#0F5D4C` | `#5CC2A6` | The one accent: primary buttons, selection, links |
| Money in | `#1D7A4E` | `#6BCB98` | Income amounts, "paid" |
| Money out | `#B0442E` | `#E88A75` | Overdue, errors |
| Amber | `#9A5B0C` | `#E0A54F` | Partial / needs attention |

Read semantic colours with `context.ledger.moneyIn` etc. (a `ThemeExtension`, so dark mode just works). Don't hard-code hex values in widgets.

Spacing is `Space.xs/sm/md/lg/xl/xxl` (4/8/12/16/24/32). Radii are by role: `Radii.control` 10 (buttons, inputs), `Radii.container` 14 (cards, sheets), `Radii.pill` (chips, status).

## Type
**IBM Plex Sans**, bundled in `assets/fonts` (SIL OFL licence in `assets/fonts/OFL.txt`). Its digits are tabular by default, so amounts align in columns without extra settings.

The scale lives in `AppTheme._textTheme`. Headings are semi-bold (600), body text is regular (400). Labels use sentence case, never ALL CAPS. The printed invoice (`InvoiceDocument`) is the one exception, because uppercase column headers are an invoice convention.

## Signature: ledger money
Always show amounts with `MoneyText`, not `Text(money(x))`. It renders RM and the cents smaller and in Slate, so the whole amount reads first. Use `emphasis: hero / large / normal` for size, `showSign: true` for +/− movements, and `color:` for money in or out.

`money()` stays for plain strings (snackbars, button labels, semantics).

## Patterns
- **Lists:** rows inside one card, separated by hairline dividers (`divided(...)`), not one card per row.
- **Leading visuals:** `InitialsAvatar` for people and businesses, `IconBadge` for things.
- **Dates in lists:** relative wording (`relativeDue`: "Due in 5 days", "12 days overdue") and `fmtDateShort`. Full dates go on the document itself.
- **Empty lists:** always use `EmptyState`. Say what's missing and offer the next action ("Add customer"), never just "No data".
- **App bar actions:** wrap any non-icon button in `Center` (the AppBar stretches actions to full height).
- **Motion:** only in response to the user (chart selection, page transitions). No decorative entrance animations.
- **Status:** use `StatusChip` (a dot plus a word) and keep it off the printed invoice.
- **Planned features:** use `ComingSoon` rows inside a "Coming later" section. Be honest that the feature doesn't exist yet.
