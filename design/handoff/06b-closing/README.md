# Bundle 06b — End-of-Day + Closing History

Mobile Flutter restyle. **This folder is the *current* state, for hand-off to Claude Design.**
`reference_current-ui.html` is a token-accurate reconstruction of what ships today (open it in a browser).
Mark up / redesign on top of it and drop the redesigned hand-off file back here.

## Scope (2 screens, 3 states)

| # | State | File |
|---|-------|------|
| 1 | **End-of-Day** — review & close (open day, editable form) | `lib/presentation/mobile/screens/reports/end_of_day_screen.dart` |
| 2 | **End-of-Day** — closed (read-only + post-close) | `…/end_of_day_screen.dart` (`_ClosedView`) |
| 3 | **Closing History** — expansion list | `…/reports/daily_closing_history_screen.dart` |

> 06a (Reports hub / lists) is the sibling bundle.

## Current state — what's not migrated

Mostly raw Material: `Card` sections, `TextFormField` with filled `InputDecoration`, `ExpansionTile`
history rows, a red destructive `FilledButton`. It **is** theme-aware for status colors, but has
**no Lucide icons** and **no soft-shadow `AppCard`**. This bundle = Cupertino→Lucide + Material `Card`→`AppCard`.

## States & rules to preserve (don't design these away)

- **Open EOD form** sections, in order: **Sales** (gross / cash / non-cash → indented GCash, Maya / discounts /
  labor revenue / sales count / salmon receivable — conditional rows only show when > 0), **Expenses**, **Plate No
  Orders** (two ₱ inputs: DP + Delivery), **Cash reconciliation** (Opening float input → **Expected cash**
  emphasized → **Counted cash** required input → **Variance** row), **Notes**, then a full-width **red "Close Day"**
  button. Closing pops a confirm dialog ("cannot be edited afterward").
- **Variance color semantics (must keep):** balanced (=0) → **success-green**; short (counted < expected) →
  **error-red**; over (counted > expected) → **warning-amber**.
- **Closed read-only view:** green "Closed by {name} at {time}" banner; same Sales / Expenses / Plate / Cash cards
  as flat key-values; variance row.
- **Post-close activity** (only when sales/voids land after the day was closed): an **amber warning banner** at top
  + an **"After close"** card recomputing sales-after-close, cash-collected-after-close, and **Updated cash on hand**.
  These figures are computed — restyle only, don't touch the math.
- **Closing History:** newest-first list of expandable rows. Header = date + "Cash on hand: ₱…" + "Closed {date,time}"
  + trailing variance (same color semantics). Expanded = full key-value reconciliation + "Closed by … · {datetime}"
  + optional notes. Empty state = "No closings yet."
- Currency via `toCurrencyWithoutSymbol()` with a `₱` prefix; dates `EEE, MMM d, y` / `MMM d, h:mm a`.

## Target language

Global theme tokens at `design/handoff/maki-theme/` + patterns from bundles 01–05: soft-shadow `AppCard`,
Lucide icons, theme-aware status colors with dark parity, neutral-by-default color discipline
(color only for status semantics). Form inputs should adopt the app's field styling
(`AppRadius.field`, theme input borders) used elsewhere in the redesigned screens.
