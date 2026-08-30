# Backlog — `getSalesByDateRange` re-derives device-local days

**Raised:** 2026-08-30, after it caused a live-looking reporting bug.
**Status:** open, not started. Deliberately deferred — see "Why this is not a
drive-by fix".

---

## The defect

`SaleRepositoryImpl.getSalesByDateRange` ignores the instants it is given and
rebuilds both bounds with the **device-local** `DateTime(...)` constructor:

```dart
// lib/data/repositories/sale_repository_impl.dart:197
final start = DateTime(startDate.year, startDate.month, startDate.day);
final end   = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
```

Only `.year/.month/.day` survive. The time, and crucially the UTC/local flag,
are discarded. Every caller's carefully computed window is replaced by a day
in whatever zone the handset happens to be in.

This defeats the shop-timezone layer for every sales report. `shop_time.dart`
exists so day boundaries follow the configured shop offset rather than the
device; this method puts the device back in charge at the last hop.

## What it already cost

Passing it a *correct* shop-day-start instant is actively wrong. For shop day
2026-08-30 at UTC+8 that instant is `2026-08-29T16:00Z`, whose **UTC calendar
fields read the 29th**. The repository then queries from the 29th and returns
two days.

That is what made the mobile admin dashboard show **₱15,480** where the web
admin showed **₱8,840** — today (8,840) plus yesterday (6,640). Introduced in
`3284905`, reverted in `d586232`. It never reached a shipped APK.

The code that works today passes `businessDayProvider`'s shop **wall** value
(a `DateTime.utc` whose fields are the shop calendar day) and builds the end
with the same local constructor the repository uses. Two layering errors that
cancel. Both sites carry a comment saying so, because it reads as a bug.

## Why this is not a drive-by fix

Removing the normalization means **every caller must then pass true instants**,
and they do not today:

| Caller | Currently passes |
|---|---|
| `todaysSalesSummaryProvider` | shop wall midnight + local end-of-day |
| `sales_report_screen` daily-only path (cashier) | same |
| `salesByDateRangeProvider` | whatever the caller's `DateRangeParams` holds |
| `reorderMovementProvider` | local `todayStart` arithmetic |
| four internal callers in the repository | pass-through |

`reorderMovementProvider` (`purchase_order_provider.dart:72`) has a comment
stating it **relies** on the normalization: *"The repo normalizes endDate to
endOfDay → yesterday 23:59:59.999."* Silently changing the contract under it
would shift the reorder window by a day, which feeds purchase-order drafting.

## Fix direction

1. Change `getSalesByDateRange` to use its arguments verbatim as instants.
2. Convert every caller to pass `shopDayStartInstant` / `shopDayEndInstant`
   (or an explicit instant range) — `report_date_range.dart` already has both.
3. Give `reorderMovementProvider` explicit bounds instead of leaning on the
   normalization.
4. Consider making the mistake unrepresentable: a distinct type for a shop
   wall value, so handing one to an instant parameter fails to compile. Three
   separate sites have now made this exact swap, which points at the shape of
   the API rather than at any one author.

## Guard already in place

`test/presentation/providers/todays_summary_window_test.dart` pins the
repository's real normalization, including that a shop-day-start instant lands
a day early. It will go red if someone "fixes" the callers without fixing the
repository — which is the failure mode this entry exists to prevent.

## Related

`docs/superpowers/plans/2026-08-26-shop-timezone.md` (the layer this
undermines).
