# Bundle 08 — Expenses

Mobile Flutter restyle. **This folder is the *current* state, for hand-off to Claude Design.**
`reference_current-ui.html` is a token-accurate reconstruction of what ships today (open it in a browser).
Mark up / redesign on top of it and drop the redesigned hand-off file back here.

## Scope (3 screens, 5 states/surfaces)

| # | Surface | Source |
|---|---------|--------|
| 1 | **Expenses dashboard** (filter + totals + Recent list) | `lib/presentation/mobile/screens/expenses/expenses_screen.dart` |
| 2 | **Empty** state | same (`EmptyStateView`) |
| 3 | **Add / Edit** form | `lib/presentation/mobile/screens/expenses/expense_form_screen.dart` |
| 4 | **Delete** confirmation + swipe-to-delete reveal | `expenses_screen.dart` (`Dismissible` + `AlertDialog`) |
| 5 | **Expense history** (grouped by month-year) | `lib/presentation/mobile/screens/expenses/expense_history_screen.dart` |

Shared widgets in play: `SummaryCard` (compact totals), `AppDropdown` (category + paid-via),
`EmptyStateView` / `LoadingView` / `ErrorStateView`, and `groupExpensesByMonthYear` (`core/utils/expense_filters.dart`).

## Current state — what's not migrated

Raw Material throughout: a category `AppDropdown` filter, a three-up compact `SummaryCard` totals row, and lists
of Material `Card` + `ListTile` rows split only by margins. **Icons are Cupertino** (`doc_plaintext` on *every*
expense row, `sun_max` / `calendar` / `chart_bar` on the totals, `tag` on the filter, `AppIcons.peso` on the amount
field). **No `AppCard`, no Lucide, and no category color semantics** — every expense reads identically (same neutral
document glyph regardless of category or payment method). Swipe-to-delete uses a hard-coded `AppColors.error`
background. This bundle = Cupertino→Lucide + Material `Card`→soft-shadow `AppCard`, keeping the neutral-by-default
discipline (no per-category color invented).

## States & rules to preserve (don't design these away)

- **Dashboard layout (top→bottom):** category **filter dropdown** → three-up **totals** row → **Recent** section
  header (with **View all →**) → up to **5** most-recent expense cards → pinned bottom **Add Expense** button.
- **Category filter:** `AppDropdown`; `null` = **"All categories"**. A selected category that's no longer active
  (deactivated/deleted) is shown inline as `{name} (inactive)`, italic + muted, so old records stay readable.
  Filtering re-scopes both the list **and** the totals.
- **Totals:** Today / This Week / This Month, each a compact `SummaryCard` bound to its own `ExpenseDateRangeParams`;
  shows `…` while loading and `—` on error. Re-scopes to the active category.
- **Expense row** = one expense: leading neutral glyph, title `{description}` (single line, ellipsis), subtitle
  `{date} • {time}` on the dashboard / `{date} • {category}` in history, trailing `{amount}` (grouped currency).
  Newest first.
- **History grouping:** grouped by **month-year**; each group has a header `{Month Year}` left + `{count} • {total}`
  right. Honours an initial category passed via route query param (deep-link from dashboard **View all**).
- **Form fields (order + requiredness):** Description \*, Amount \* (decimal, must be > 0), Category \* (admin-managed
  dropdown; shows a "No categories defined — ask admin" error state when empty), **Paid via** \* (`PaymentMethod`:
  Cash / GCash / Maya / Salmon / Mixed; defaults to Cash), Date \* (date picker, max = today), Notes (optional,
  3-line). Submit label flips **Add Expense** / **Update Expense**; shows an inline spinner while saving.
- **Role gating (`RolePermissions`):** **add** (`addExpense`) — hides the bottom Add Expense button if absent;
  **edit** (`editExpense`) — enables tap-to-edit; **delete** (`deleteExpense`) — enables swipe-to-delete +
  long-press on the dashboard and the trash action in the form app-bar. Staff/cashier can view + add; admin gets
  full CRUD.
- **Delete confirmation:** every delete path (swipe, long-press, form trash) goes through an `AlertDialog`
  (`Delete "{description}"?` → Cancel / red Delete) and shows a success/error snackbar.
- Currency grouped `₱1,234.00` via the app formatter; dates `MMM d, y • h:mm a` (dashboard) and `MMM d, y` (history).
- Empty state: document icon + "No Expenses" / "Tap + to add an expense" (or "No matches" when a category filter is
  active).

## Target language

Global theme tokens at `design/handoff/maki-theme/` + the patterns shipped in bundles 01–07: soft-shadow `AppCard`
rows, Lucide icons, theme-aware status colors with **dark parity** (reuse `AppColors` + their `*OnDark` variants),
and **neutral-by-default discipline** — color only carries status meaning, so expense rows stay neutral (do not
invent per-category colors). Totals can keep the elevated `SummaryCard` treatment. App bar stays flat on canvas.
