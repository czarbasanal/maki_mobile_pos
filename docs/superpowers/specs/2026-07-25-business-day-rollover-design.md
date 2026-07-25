# Business-day rollover: today-scoped data refreshes at midnight

Date: 2026-07-25
Surface: Flutter mobile only. No schema/rules changes.

## Problem

"Today" is computed with `DateTime.now()` at build/provider-creation time
all over the app. A screen or provider alive across midnight keeps serving
yesterday: dashboard figures, EOD (`_today`), today-locked sales history,
top-selling, avg-daily. Worst case: a stale EOD screen can close
"yesterday" after the flip. (Context: an unclosed day can never be closed
retroactively — the close-day UI only targets today — so stale-day actions
are costly.)

## Decision (confirmed with user)

All today-scoped data follows one central business-day source that rolls
over at midnight in-session AND re-checks on app resume.

## Design

1. **`businessDayProvider`** (`lib/presentation/providers/business_day_provider.dart`):
   a `Notifier`-style provider exposing the current business DATE
   (midnight-truncated `DateTime`).
   - On init: emits today's date and arms a `Timer` for the next midnight
     (+1s guard); on fire, re-emits and re-arms.
   - App-resume re-check: a `WidgetsBindingObserver` hook (registered from
     the app root or inside the notifier) re-compares on
     `AppLifecycleState.resumed` and emits if the date changed.
   - Time injection: the notifier takes a `DateTime Function() now` seam
     (overridable in tests) so midnight flips are unit-testable with a
     fake clock. Pure helper `DateTime nextMidnightAfter(DateTime)` in
     `lib/core/utils/` with its own unit tests.
2. **Consumers** swap their `DateTime.now()`-derived "today" for
   `ref.watch(businessDayProvider)`:
   - `todaysSalesSummaryProvider`, `todaysSalesProvider` (range derivation)
   - `topSellingTodayProvider` (derives from todaysSales — verify chain)
   - `monthToDateSummaryProvider` + `avgDailySalesProvider` (`daysElapsed`)
   - `dailyClosingDataProvider`'s isToday comparison
   - EOD screen `_today` getter (screen re-points to the new day at flip —
     review mode for the fresh day; kills the stale-close hazard)
   - Dashboard date header + any dashboard `_today` locals
   - Sales History daily-only forced range
   - Sweep rule: grep `DateTime.now()` under `lib/presentation/` +
     providers; classify each hit today-scope (swap) vs timestamp/one-shot
     (keep — e.g. createdAt stamps, report preset computed at tap-time,
     PO velocity windows computed per fetch). Record the classification.
3. **Invalidations**: watching the provider makes dependent
   FutureProviders recompute automatically on flip; no manual invalidate
   fan-out.

## Not changing

Sale/closing business-date assignment semantics (writes already use
DateTime.now() at write time — correct), report presets, PO velocity
windows, web admin.

## Testing

- Unit: `nextMidnightAfter` (incl. DST-less PH assumption: plain next
  00:00), notifier flip with fake clock, resume re-check emits on change
  and stays silent when same day.
- Provider: overriding `businessDayProvider` and flipping it recomputes
  `todaysSalesSummaryProvider` (fake repo counts calls) and changes the
  EOD screen's watched date.
- Widget: dashboard header shows the new date after a flip (pump with
  overridden provider, change value, pump).
