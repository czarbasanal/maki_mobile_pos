# End-of-Day Closing Report — Design

**Date:** 2026-05-28
**Status:** Approved (pending spec review)

## Problem

The business needs an end-of-day report that shows, for a given business day:

1. **Gross sales** (exact amount)
2. **Total expenses** for the day
3. The **remaining actual money** — i.e. physical **cash on hand**

"Remaining actual money" means *physical cash in the drawer*, not a P&L net figure.
Digital sales (GCash / Maya / card) never enter the drawer, so they are excluded
from the cash-on-hand calculation.

This is a saved, once-per-day **daily closing** that reconciles the **sales drawer**.
It is mobile-first.

### Relationship to petty cash

The existing **petty cash** feature is a *separate small-expense fund* (manual cash
in/out with its own running balance and a cut-off that zeroes the fund). It is wired on
web (admin-only, `managePettyCash`) and not surfaced in mobile navigation.

The End-of-Day Closing is **independent** and reconciles the *sales drawer*, not the
petty cash fund. Petty cash is left untouched by this work. The two features do not
share data or screens.

## Core formula

For a given business day:

```
cash sales    = salesSummary.byPaymentMethod[PaymentMethod.cash]
cash expenses = sum(expense.amount for expenses that day where paidVia == cash)

expected cash = opening float + cash sales − cash expenses
variance      = counted cash − expected cash
```

- `opening float` and `counted cash` are entered manually by the user at close time.
- Voided sales are already excluded by the existing sales summary computation; the
  closing inherits that behavior.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Meaning of "remaining actual money" | **Cash on hand** (physical cash; digital sales excluded) |
| Opening float | **Manual entry** at close time |
| Expense payment tracking | **Add a `paidVia` payment field to expenses**; only cash-paid expenses reduce cash on hand |
| Persistence | **Saved daily record** (close once per day; snapshot + history) |
| Access | **Cashier, staff, and admin** can view AND close |
| Petty cash relationship | **Keep separate; petty cash untouched** |
| Architecture | **Full clean-architecture feature** mirroring the petty cash / expense pattern |

## Data model

### New entity: `DailyClosingEntity`

Firestore collection `daily_closings`, document id = `YYYY-MM-DD` (the business date).
One document per day enforces the once-per-day rule.

| field | type | meaning |
|---|---|---|
| `id` | String | doc id (business date, `YYYY-MM-DD`) |
| `businessDate` | DateTime | the day being closed (date-only) |
| `grossSales` | double | gross sales, all payment methods |
| `netSales` | double | net of discounts, all methods |
| `totalDiscounts` | double | total discounts that day |
| `cashSales` | double | cash-method sales |
| `nonCashSales` | double | gross − cash sales (digital) |
| `totalExpenses` | double | all expenses that day |
| `cashExpenses` | double | expenses with `paidVia == cash` |
| `openingFloat` | double | manual entry |
| `expectedCash` | double | openingFloat + cashSales − cashExpenses |
| `countedCash` | double | manual entry (physical count) |
| `variance` | double | countedCash − expectedCash |
| `salesCount` | int | number of completed sales |
| `voidedCount` | int | number of voided sales |
| `notes` | String? | optional |
| `closedBy` | String | user id |
| `closedByName` | String | user display name |
| `closedAt` | DateTime | timestamp of close |

### Expense change: add `paidVia`

Add `paidVia` (`PaymentMethod`, default `cash`) to:

- `ExpenseEntity` (domain) — new field, defaults to `PaymentMethod.cash`
- `ExpenseModel` (data) — serialize/deserialize; **missing field defaults to `cash`** on
  read for backward compatibility with existing records
- The expense form screen — a payment-method selector (default `Cash`)

Only expenses with `paidVia == cash` count toward `cashExpenses`.

## Domain & data layers

Mirrors the petty cash / expense pattern.

- **`DailyClosingModel`** — Firestore (de)serialization, `toEntity()` / `fromEntity()`.
- **`DailyClosingRepository`** (domain interface) + **`DailyClosingRepositoryImpl`** (data):
  - `getClosing(DateTime date)` → existing closing or `null`
  - `saveClosing(DailyClosingEntity)` → write doc (id = date)
  - `watchClosings({int limit})` → history stream, newest first
- **Use cases** (each gates permission via the actor, like `GetSalesReportUseCase`):
  - `GetDailyClosingSummaryUseCase(date)` — computes the **live, unsaved** figures by
    pulling the sales summary + the day's expenses (with cash split). Returns a
    `DailyClosingDraft` (computed fields only; no float/counted yet). Drives the review
    screen before closing.
  - `CloseDayUseCase(date, openingFloat, countedCash, notes)` — recomputes figures,
    builds the entity, persists it, writes an activity log (`closeDay`). **Rejects if the
    day is already closed** (once-per-day).
  - History read flows through the repository stream.

Computation lives in the use cases (testable in isolation), not the UI.

### `DailyClosingDraft`

A lightweight value object with the computed fields (gross/net/discounts, cash &
non-cash sales, total & cash expenses, salesCount, voidedCount). The screen layers the
manual inputs (opening float, counted cash) on top, computes `expectedCash` and
`variance` live for display, and passes them to `CloseDayUseCase` on confirm.

## Providers

New `daily_closing_provider.dart`:

- `dailyClosingRepositoryProvider`
- `getDailyClosingSummaryUseCaseProvider`, `closeDayUseCaseProvider`
- `dailyClosingDraftProvider.family<DailyClosingDraft, DateTime>` — live computed figures
- `dailyClosingForDateProvider.family<DailyClosingEntity?, DateTime>` — saved closing for a date
- `dailyClosingHistoryProvider` — stream of past closings
- `DailyClosingOperations` notifier — wraps `closeDay`; on success invalidates the draft,
  history, the per-date provider, and `todaysSalesSummaryProvider` (same invalidation
  style as `PettyCashOperations`)

## UI & navigation

Two screens, mobile-first, styled like the existing report screens. Neutral surfaces;
color reserved for variance/status (per the project's color discipline).

### `EndOfDayScreen` (`/reports/end-of-day`)

Review + close flow for the current business day:

- **Sales block:** gross sales (exact), cash vs non-cash split, discounts, sales count.
- **Expenses block:** total expenses, with the cash portion called out.
- **Cash reconciliation block:** opening float (input) → expected cash (computed) →
  counted cash (input) → **variance**, color-coded (green = exact, red = short,
  amber = over) matching the cut-off dialog.
- **Close Day** button → confirmation → persists.
- If the day is **already closed**, the screen shows the saved record read-only with a
  "Closed by X at HH:MM" banner.

### `DailyClosingHistoryScreen` (`/reports/end-of-day/history`)

List of past closings (date, cash on hand, variance chip). Tap → read-only detail that
reuses the same blocks.

### Entry points

- A tile on the **Reports** screen ("End-of-Day Closing").
- A **dashboard quick action** ("Close Day").

Both are gated so only permitted roles see them.

## Permissions & rules

- **Permissions:** add `viewEndOfDay` and `closeDay` to the `Permission` enum; grant
  **both** to admin, staff, and cashier. Wire into `route_guards.dart` for the new routes.
- **Firestore rules:** new `daily_closings` collection block — read for authenticated
  admin/staff/cashier; create/update gated to the same roles; mirrors the
  `void_requests` / petty cash rule style.

## Testing

- Unit tests for the two use cases:
  - `GetDailyClosingSummaryUseCase`: cash/non-cash split, total vs cash expenses,
    voided-sale handling, permission gating.
  - `CloseDayUseCase`: expected-cash + variance computation, the **already-closed**
    rejection, activity-log write, permission gating.
- UI verified manually in the running app.

## Out of scope

- Changes to the petty cash feature.
- Surfacing petty cash on mobile.
- Retroactively editing a closed day (closings are immutable once saved; history is
  read-only).
- Multi-branch scoping (handled by the separate multi-branch architecture work).
