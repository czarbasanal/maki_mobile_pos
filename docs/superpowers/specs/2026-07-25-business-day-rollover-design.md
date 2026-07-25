# Business-day rollover + unsettled-drawer enforcement

Date: 2026-07-25 (v3 — user chose SERVER-HARD enforcement via a
denormalized state doc; supersedes v2's client-only gate)
Surface: Flutter mobile + firestore.rules (new `drawer_state` collection +
a sales-create guard; deploy user-gated).

## Problem

1. "Today" is computed at build/provider-creation time all over the app; a
   screen or provider alive across midnight keeps serving yesterday.
2. An unclosed drawer becomes permanently unclosable at midnight (the EOD
   screen only targets today), the missing reconciliation surfaces as a
   variance surprise on the NEXT close, and nothing stops the shop from
   ringing new sales on top of an unsettled drawer.

## Decisions (confirmed with user)

- All today-scoped data follows one central business-day source (midnight
  timer + app-resume re-check).
- Past 12am with the previous day unclosed: a warning banner prompts the
  cashier to close the drawer, with a button routing to End-of-Day closing.
- New SALE CREATION is blocked until the previous day is settled: POS
  checkout AND JO bill-out (both create sales). Browsing, cart edits,
  saving/editing JO tickets, receiving, and expenses stay allowed.
- Unsettled = any past business day with ≥1 COMPLETED sale and no closing
  record. Shop-closed (zero-sale) days never block. Multiple open days are
  settled oldest-first; the banner names the date being closed.

## Design

### A. `businessDayProvider` (the clock)

`lib/presentation/providers/business_day_provider.dart` — a Notifier-style
provider exposing the current business DATE (midnight-truncated).
- Emits today's date on init; arms a `Timer` for next midnight (+1s guard),
  re-emits and re-arms on fire.
- `WidgetsBindingObserver` hook re-compares on `AppLifecycleState.resumed`.
- Injectable `DateTime Function() now` seam for tests; pure helper
  `nextMidnightAfter(DateTime)` in `lib/core/utils/` with unit tests.

### B. Today-scoped consumers follow the clock

Swap `DateTime.now()`-derived "today" for `ref.watch(businessDayProvider)`
in: `todaysSalesSummaryProvider`, `todaysSalesProvider`,
`topSellingTodayProvider` (verify chain), `monthToDateSummaryProvider` +
`avgDailySalesProvider`, `dailyClosingDataProvider`'s isToday comparison,
dashboard date header/locals, Sales History daily-only forced range.
Sweep rule: grep `DateTime.now()` under `lib/presentation/` + providers;
classify each hit today-scope (swap) vs timestamp/tap-time/one-shot (keep);
record the classification. Write-time timestamps (sale/closing createdAt)
are UNCHANGED.

### C. Unsettled-day detection

`unsettledBusinessDayProvider` → `DateTime?` (the OLDEST unsettled day, or
null when clear):
- Find the latest closing (`daily_closings` ordered desc, limit 1).
- Candidate window: from the day after that closing (or `businessDay − 14`
  if no closing exists / the gap exceeds it — a bounded 14-day scan cap,
  documented) through yesterday.
- For each candidate day (oldest first): one `limit(1)` completed-sales
  query for that day; first day with a sale and no closing wins.
  (Per-day closing existence: fetch closings in the window once, by doc id
  = date string — cheap.)
- Recomputes when `businessDayProvider` flips and when
  `dailyClosingForDateProvider`/close-day invalidations fire (watch the
  same invalidation the close-day flow already triggers).

### D. Banner + sale-creation block

- `UnsettledDrawerBanner` (shared widget): warning-styled, text names the
  date — "Yesterday's drawer (Jul 24) hasn't been closed. Close it before
  new sales." — with a "Close Day" button routing to EOD targeting that
  date. Shown on the POS screen (above the cart area) and the dashboard
  (below the header) whenever `unsettledBusinessDayProvider != null`.
- Block (client layer): `canProceedToCheckout` gains `&& !hasUnsettledDay`
  (cart gate); the JO bill-out button disables and `_billOut`
  early-returns with the same warning when an unsettled day exists.
- Everything else (JO save/edit, receiving, expenses, reports) unaffected.

### D2. Server-hard enforcement — `drawer_state` doc (user-chosen)

Single doc `drawer_state/state` with integer business days (PH = UTC+8,
no DST; `yyyymmdd` ints so rules compare without string padding):
- `lastSaleDay: int` — business day of the most recent completed sale;
  written INSIDE the sale-create transaction (`tx.set(merge)`), value
  MUST equal the rules-computed current PH day.
- `lastClosedDay: int` — business day of the most recent closing; written
  in the close-day batch/transaction, value must be ≤ current PH day.

Rules:
- Helper `phDay()` = `request.time + duration.value(8, 'h')` →
  `year*10000 + month*100 + day`.
- `drawer_state` read: any active valid user. Create/update: any active
  valid user, constrained per field — a write touching `lastSaleDay` must
  set it to `phDay()`; a write touching `lastClosedDay` must set it ≤
  `phDay()`. No delete.
- `sales` create gains `&& drawerSettled()` where `drawerSettled()` =
  state doc missing (fresh DB) OR `lastSaleDay == phDay()` (sales already
  today — day is live) OR `lastClosedDay >= lastSaleDay` (latest sales-day
  settled). This blocks a new sale whenever the most recent sales-day is a
  PAST day without a closing — server-side, unbypassable.

Boundaries (documented):
- The rule enforces the LATEST-sales-day invariant; the client detector
  (§C) remains the source of truth for the OLDEST unsettled day and the
  banner. With oldest-first settling they agree.
- Old APKs (≤ +15) neither update `drawer_state` nor gate client-side:
  their sales pass the rule while the drawer is settled but don't advance
  `lastSaleDay` (a detection gap, not a corruption) — retire old installs
  promptly via App Distribution.
- Missing doc ⇒ allow (lazy creation on the first post-update sale/close;
  no backfill needed).
- Rules deploy is a separate, user-confirmed step. Required order: rules →
  hosting (web) → APK, and the APK must land on ALL devices in the SAME
  session — not a rolling rollout. An old APK that doesn't write
  `drawer_state` can still close a day after the new rules + doc exist,
  which bricks sales on every device (old or new) with no banner, since
  `drawerSettled()` denies with a bare `permission-denied` and nothing
  local ever told the old APK a day needed closing. Retire old installs
  the same day the rules deploy.

### E. EOD screen closes a TARGET day (not always today)

- `EndOfDayScreen` gains a target date: defaults to the oldest unsettled
  day when one exists, else today. Route accepts an optional date (banner
  passes it); the screen header shows which date is being closed when it
  isn't today ("Closing Jul 24").
- The target is LOCKED when the screen opens: a midnight flip mid-close
  does not retarget the form (protects an in-progress count). Reopening
  recomputes the default.
- Close path: existing `CloseDayUseCase.execute(date: target)` — verify at
  plan time it has no today-assertion (its data source
  `GetDailyClosingSummaryUseCase` already supports past dates).
- After closing an unsettled day, the provider chain recomputes: banner
  clears (or advances to the next unsettled day), sales unblock.

## Not changing

Write-time business-date assignment, report presets, PO velocity windows,
web admin (web POS sale creation WILL hit the new rule once deployed —
web's checkout must also write `drawer_state.lastSaleDay` in its create
transaction, or web sales fail after the first mobile sale creates the
doc: include the small web write in the plan).

## Testing (TDD; tests mirror lib/)

- Unit: `nextMidnightAfter`; notifier flip with fake clock; resume
  re-check (change vs same-day).
- Unsettled detection: no closings + no sales → null; gap day with sales →
  that day; zero-sale gap day skipped; multiple gaps → oldest; closing the
  day clears/advances; 14-day cap respected (fake repo fixtures).
- Widget: banner renders with date + routes with target; POS checkout and
  JO bill-out disabled while unsettled (and re-enabled after fake close);
  EOD header shows the target date; mid-open flip does not retarget the
  EOD form; dashboard shows the banner.
- Provider: flipping businessDay recomputes today-scoped providers (fake
  repo call counts).
- Rules (emulator suite): drawer_state field constraints (lastSaleDay must
  equal phDay; lastClosedDay ≤ phDay; no delete); sales create denied when
  lastSaleDay is a past day > lastClosedDay; allowed when doc missing /
  same-day / settled; spoofed lastSaleDay values rejected.
