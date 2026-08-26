# Shop timezone — enforce Philippine Standard Time system-wide (configurable)

**Date:** 2026-08-26
**Status:** Approved design
**Branch:** `feat/shop-timezone`

## Problem

The system's business-day and date logic is split three ways today:

- **Firestore rules** compute the business day correctly: `phDay()` = `request.time + 8h` (true UTC+8, device-independent).
- **Web admin** mostly matches (`phDayInt` does UTC+8 epoch math) but has browser-local stragglers: `saleNumber.counterKey` (inconsistent with `phDayInt` **inside the same sale transaction**), `payPeriod.ts`, `ActivityLogsPage` Today/Yesterday grouping, `resolvePreset` date ranges, and a `new Date("yyyy-MM-dd")` UTC-parse off-by-one in `DateRangePicker`.
- **Flutter mobile** reads the device's local clock fields everywhere (`business_day.dart`, `dateRangeForPreset`, sale counter keys, closing doc IDs, `datetime_extensions`). A comment in `sale_repository_impl.dart` states the assumption outright: "Assumes the device clock is PH-local."

Consequence: a device set to a non-PH timezone computes the wrong business day. Worst case is not cosmetic — the sale's `drawer_state` write fails the rules check (`lastSaleDay == phDay()`), so **the sale hard-fails**.

## Goal

All calendar computations ("what day is it", range boundaries, day grouping, "is today") follow a single **shop timezone**, defaulting to Asia/Manila (UTC+8, no DST), regardless of device/browser timezone — configurable by an admin in settings.

## Core principle

Stored timestamps never change meaning — they remain absolute instants (Firestore `Timestamp` / `serverTimestamp`). Only instant→calendar conversions change, and they all route through one *shop clock* per surface.

Two representations, strictly separated:

- **Instant** — a real point in time. What is written to / read from Firestore. Untouched by this feature.
- **Shop-time view** — an instant shifted by `tzOffsetMinutes`, used only for day math, range boundaries, and display. **Never persisted.** Range boundaries computed in shop time are converted back to instants before use in Firestore queries (`Timestamp.fromDate`).

## 1. Settings document

`settings/general` (already declared in `firestore_collections.dart` as `generalSettings`, currently unused):

```
timezone: "Asia/Manila"     // IANA name — for client display and the picker
tzOffsetMinutes: 480        // used for all day math; readable by rules
updatedAt: <serverTimestamp>
updatedBy: <uid>
```

- Readable by all authenticated active users.
- Writable by admin only; rules validate `tzOffsetMinutes` is an int in [-720, 840].
- Seeded (one-off script) **before** any rules/client change ships.

## 2. Flutter mobile

New pure module `lib/core/utils/shop_time.dart`:

- `toShopTime(DateTime instant, int offsetMinutes)` → DateTime whose *fields* read shop-local (derived via UTC + offset; marked so it is used for field math/display only).
- `shopInstantOf(DateTime shopFieldsDateTime, int offsetMinutes)` → real instant for a shop-local wall time (inverse; used for query boundaries and timer arming).
- Shop-aware `startOfDay/endOfDay/startOfWeek/Month/Quarter/Year` counterparts.

Providers:

- `shopTimezoneProvider` — streams `settings/general`; defaults to `{Asia/Manila, 480}` when the doc is missing; caches last value in SharedPreferences so offline cold-starts still use the shop offset.
- `nowProvider` stays the injectable raw clock; new `shopNowProvider` composes it with the offset.

Rewired seams (not all ~138 `DateTime.now()` sites — most are harmless deserialization fallbacks):

- `business_day.dart` (`businessDayInt`, `businessDateOf`, `nextMidnightAfter`) + `business_day_provider` — rollover `Timer` arms at *shop* midnight converted back to a real instant; `recheck()` on resume unchanged.
- `unsettled_day_provider` — day scan in shop time.
- `sale_repository_impl` — `_getDateKey` (counter key) and `hasCompletedSaleOn` (query window = shop-midnight bounds → instants).
- `daily_closing_repository_impl` — `docIdFor` in shop time.
- `report_date_range.dart` `dateRangeForPreset` — all 9 presets computed in shop time; boundaries returned as instants.
- `datetime_extensions.dart` (`isToday`, `isYesterday`, `toRelativeTime`, `startOfDay`…) and report/activity screens' day grouping.

`createdAt`-style writes stay as-is where they are real instants; prefer `FieldValue.serverTimestamp()` opportunistically where trivially safe (e.g. `activity_logger.dart`).

## 3. Web admin

- New `src/domain/time/shopTime.ts` built on the already-installed (and currently unimported) `date-fns-tz`, fed by a settings context that loads `settings/general` (default Asia/Manila).
- Routed through it: `resolvePreset` (all presets in shop tz, boundaries as instants), `saleNumber.counterKey` (must agree with `phDayInt` in the same transaction), `payPeriod.ts`, `ActivityLogsPage` day grouping, `DateRangePicker` date-string parsing fix.
- `phDayInt` takes the offset from settings instead of hardcoding +8.
- **Settings UI:** Settings → General → "Time & timezone", admin-only (gated-route pattern: `routePaths.ts` + `routes.tsx` + `routeGuards.ts`). Picker over a curated list of fixed-offset (no-DST) timezones, default Asia/Manila, live current-shop-time display. Saving writes `timezone` + derived `tzOffsetMinutes`. The page notes that changing the timezone requires all devices to run a supporting APK.

## 4. Firestore rules

- `phDay()` reads `settings/general.tzOffsetMinutes` via `get()`, falling back to 480 when the doc/field is absent. Cost: one extra read per `drawer_state` write evaluation (~one per sale — negligible).
- Add read/write clauses for `settings/general` (read: authenticated active users; write: admin, with `tzOffsetMinutes` int-range validation).

## 5. Rollout order (backward compatibility)

Old APKs compute the business day from the device clock assuming PH-local; with the default staying Asia/Manila, their behavior is unchanged.

1. Seed `settings/general` (one-off script).
2. Deploy rules (fallback-safe either way). *Production-affecting — confirm with the user before deploying.*
3. Web admin changes + hosting deploy.
4. Mobile changes + next APK.

Operational caveat: if the admin ever changes the timezone away from Asia/Manila, phones on pre-feature APKs will start failing drawer writes — same forced-upgrade class as the +21 job-orders cutover. The settings page states this.

## 6. Testing

TDD per surface:

- Unit tests on the pure shop-time functions with fake offsets simulating a non-PH device (e.g. UTC-5).
- Regression test: `businessDayInt(toShopTime(instant, 480))` equals the rules' `phDay()` for the same instant, across day-boundary edge cases.
- Updated tests for `dateRangeForPreset` / `resolvePreset` boundary→instant conversion.
- Vitest coverage for `counterKey`, `payPeriod`, and the `DateRangePicker` parse fix.
- Verification: `flutter test` + `flutter analyze`; `npm run typecheck` + `npm run test` in `web_admin/`.

## Out of scope

- DST-zone support (curated no-DST picker instead).
- Migrating stored data — none needed; stored instants are unchanged.
- Auditing all ~138 `DateTime.now()` deserialization-fallback sites.
