# Bundle 06a — Reports (hub / lists)

Mobile Flutter restyle. **This folder is the *current* state, for hand-off to Claude Design.**
`reference_current-ui.html` is a token-accurate reconstruction of what ships today (open it in a browser).
Mark up / redesign on top of it and drop the redesigned hand-off file back here.

## Scope (4 screens)

| # | Screen | File |
|---|--------|------|
| 1 | **Sales History** (list) | `lib/presentation/mobile/screens/reports/sales_list_screen.dart` |
| 2 | **Sales Report** (dashboard) | `…/reports/sales_report_screen.dart` |
| 3 | **Profit Report** | `…/reports/profit_report_screen.dart` |
| 4 | **Top Selling** (drill-down) | `…/reports/top_selling_screen.dart` |

Shared widgets in scope (used by the above):
`…/widgets/reports/date_range_picker.dart`, `sales_summary_card.dart`, `top_products_card.dart`.

> 06b (End-of-Day + Daily Closing History) ships as a separate bundle.

## Current state — what's already done vs. not

**Already on the new language:** theme-aware `colorScheme`, **dark-mode hairline parity**
(`AppColors.darkHairline/lightHairline`), outlined metric/rank cards, semantic accents
(success-green profit, error-red voids), and the amber/silver/bronze **medal idiom** for top-3 ranks.

**Not migrated (this bundle's job):**
- Icons are still **Cupertino** → migrate to **Lucide** (`LucideIcons.*`).
- Container surfaces are Material `Card` (flat elevation) → migrate to soft-shadow **`AppCard`**
  (`lib/presentation/shared/widgets/common/app_card.dart`): light = shadow, dark = `darkCard` + 1px hairline.

## States & rules to preserve (don't design these away)

- **Date filtering** — `DateRangePicker` = preset dropdown + active-range pill (both outlined in primary/slate;
  tapping the pill opens a custom range). Defaults: Sales History/Report = *Today*, Top Selling = *This Month*,
  Profit Report = last 30 days via a flat date strip with a "Change" button.
- **Role gating (must keep):**
  - Daily-reports-only roles: the date picker is replaced by a *"Showing today's sales only"* warning banner; range is forced to today.
  - **Admin-only** metrics: `Total Cost`, `Gross Profit (+ margin)`, `Service Revenue/Profit`, and the green
    per-row **profit badge** on Top Selling. Cashier/staff never see cost or profit.
- **Sales History** — sales grouped by day with a flat header (date + sale count + day total in primary).
  Each row: leading glyph (file-text, or red x-circle for voided), sale number (+ outlined `VOID` badge,
  strikethrough when voided), `time • cashier • N items`, trailing grand total + payment-method icon/label.
- **Sales Report** — Sales Summary card, Top Selling card (Top 10), Payment Methods breakdown (progress bars),
  and an End-of-Day Closing link tile.
- **Top Selling** — same Top Products card, capped at 20; per-row rank medal, qty/revenue, quantity progress bar.
- **Profit Report** — currently shows a static `₱0.00` scaffold + "No profit data available" empty state
  (data wiring is out of scope; restyle the shell only).
- Currency stays grouped (`₱1,234.00`) via the app-wide formatter; SKUs in `Roboto Mono`.

## Target language

Global theme tokens at `design/handoff/maki-theme/` and the patterns established in bundles 01–05:
soft-shadow `AppCard`, Lucide icons, hero numbers where a single value dominates, theme-aware status colors with
dark parity, neutral-by-default color discipline (color only for status semantics / role meaning).
