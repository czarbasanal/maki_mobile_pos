# End-of-Day Itemized Expenses — include by default, removable, add-in-place

**Date:** 2026-07-04
**Backlog:** #13 — "expenses added via expenses within that day should be added by default in
close day summary but it can be removed. user can also add expenses through end of day report."
**Surface:** Mobile (Flutter) only — daily closing exists only on mobile.
**Decision CONFIRMED by user 2026-07-04:** "remove" = the expense stays recorded in the
Expenses ledger but is **not deducted from the drawer** — excluded from this closing's math
entirely. Deleting an expense remains a separate action on the Expenses screen.

## Current behavior (what already works)

`GetDailyClosingSummaryUseCase` fetches the day's expenses and `DailyClosingDraft.fromData`
folds them into `totalExpenses` / `cashExpenses`; `expectedCashFor` subtracts cash expenses
from expected drawer cash. The EOD screen (`end_of_day_screen.dart`) shows only two aggregate
rows. `CloseDayUseCase` re-fetches and recomputes at close time. `PostCloseActivity` diffs the
saved snapshot against a freshly computed draft.

**Gap:** the individual expenses are invisible in the EOD flow, nothing can be excluded, and
adding an expense means leaving the screen.

## Data model

- `DailyClosingEntity` (+ `DailyClosingModel`): new `final List<String> excludedExpenseIds`
  (default `const []`). Serialized in `toCreateMap` / read in `fromMap` (tolerant: missing →
  empty). Closing docs stay immutable; field rides the create — **no firestore.rules change**
  (`daily_closings` create is already open to active users).
- `DailyClosingDraft` unchanged — it stays a pure computation over whatever expense list the
  caller passes (callers filter).

Rationale for persisting the ids: `PostCloseActivity.between` compares the snapshot against a
recomputed current draft. Without the ids, an excluded ₱500 cash expense would surface as
phantom "cash expenses after close" drift forever.

## Summary layer — fetch/derive split

- `GetDailyClosingSummaryUseCase` returns a new result type
  `DailyClosingData { SalesSummary summary, List<ExpenseEntity> expenses, DateTime businessDate }`
  instead of a pre-baked draft.
- The EOD screen holds `Set<String> _excludedIds` (session-local until close) and derives
  `DailyClosingDraft.fromData(summary, includedExpenses)` in build — remove/restore recomputes
  totals, expected cash, and variance instantly with **no refetch** (same pattern as the PO
  cover-days split).
- `CloseDayUseCase.execute` gains `Set<String> excludedExpenseIds` (default empty): filters the
  fetched expenses before `fromData`, stamps the ids onto the saved entity/doc.
- Closed view / drift: wherever the "current draft" for `PostCloseActivity.between` is
  computed, filter out `closing.excludedExpenseIds` first.

## UI — EOD review section

Replace the aggregate-only Expenses card with an itemized card:

- One row per expense of the day: description, amount, payment-method tag (cash rows are the
  ones that touch the drawer), and a remove (✕) affordance.
- Removed rows stay visible but greyed/struck with a **Restore** action (until the day is
  closed; exclusions are not persisted anywhere until the closing is saved).
- Card footer keeps the existing `Total expenses` / `Cash expenses` rows, now reflecting
  included-only figures.
- **Add expense** button on the card → `context.push(RoutePaths.expenseAdd)` (full existing
  form, receipt photo included) → on return, re-run the summary fetch; the new expense appears
  in the list, included by default.
- Empty state: "No expenses today" + the Add button.

The closed view (`_ClosedView`) keeps its aggregate rows (itemizing the historical record is a
possible later enhancement, not in scope). Its post-close drift figures use the
exclusion-aware recompute above.

## Permissions / roles

No new gates: EOD screen already requires `closeDay` (all roles have it); Add reuses
`addExpense` (all roles); exclusion is part of composing the closing, which any closer can do.

## Error handling

- Summary fetch failure: existing error state unchanged.
- Close failure: unchanged (exclusions stay in local state, nothing half-saved).
- An expense deleted elsewhere mid-review simply disappears on next refresh; stale excluded
  ids in a saved closing are harmless (filter no-ops).

## Testing

- `DailyClosingDraft.fromData` with a filtered list (already pure — cover via screen-derive test).
- `CloseDayUseCase`: excluded ids filter the math and land on the saved entity.
- `DailyClosingModel`: `excludedExpenseIds` round-trip + missing-field tolerance.
- `PostCloseActivity`: excluded expense produces zero drift.
- Widget tests: rows render; ✕ recomputes totals/expected cash instantly; Restore brings a row
  back; Add button pushes the expense form route; empty state.
- Full `flutter test` + `flutter analyze` green.

## Delivery

One branch (`feat/eod-itemized-expenses`). No rules deploy, no web change. Device smoke = user.
