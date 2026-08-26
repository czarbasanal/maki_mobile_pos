# Shop Timezone Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every calendar computation in the system (business day, date keys, doc IDs, query windows, report ranges, day grouping, display) follow one shop timezone — default Asia/Manila (UTC+8) — regardless of the device's or browser's timezone, with the zone configurable by an admin in settings.

**Architecture:** Stored timestamps stay absolute instants and are never rewritten. Each surface gains one pure "shop time" module that converts between an *instant* and a *shop wall-clock view* (the instant shifted by the shop's offset, whose date/time fields read shop-local). Day math and display use the wall view; anything written to Firestore or used as a query bound is converted back to an instant first. The offset lives in `settings/general` (`tzOffsetMinutes`, default 480) and is read by mobile, web, and the Firestore rules, so client and server agree on "today".

**Tech Stack:** Flutter + Riverpod + cloud_firestore + shared_preferences (mobile); React + TypeScript + Vitest + firebase/firestore (web); Firestore security rules tested with `@firebase/rules-unit-testing` + Mocha (`tools/firestore-rules-test`); Node `firebase-admin` scripts (`scripts/`).

**Spec:** `docs/superpowers/specs/2026-08-26-shop-timezone-design.md`

## Global Constraints

- Shop-time default is **Asia/Manila, `tzOffsetMinutes: 480`**. Every fallback, every seed, every "doc missing" path must resolve to 480 — this is what keeps existing APKs and the current rules behaviour unchanged.
- Firestore field names: `settings/general` holds `timezoneId` (string, IANA name) and `tzOffsetMinutes` (int). Same names in Dart, TypeScript, rules, and the seed script.
- `tzOffsetMinutes` valid range: **-720 .. 840** inclusive. Enforced in rules and in both UIs.
- Only **fixed-offset (no-DST) timezones** are offered. The curated catalog is duplicated in Dart and TypeScript and must stay in lock-step (same ids, same offsets) — the repo already uses this mirroring convention (`routePaths.ts` mirrors `route_names.dart`).
- **Never persist a shop wall-clock value.** Wall values are `isUtc` DateTimes (Dart) / offset-shifted `Date`s read with `getUTC*` (TS). Convert with `instantOf(...)` before `Timestamp.fromDate`, before a Firestore query bound, and before anything that ends up in a document.
- Mobile display formatting uses `DateFormat(...).format(instant.inShopTime)`. Web display formatting uses `Intl.DateTimeFormat('en-PH', { ..., timeZone })`. Do not use `date-fns` local-time helpers (`startOfDay`, `endOfDay`, …) on wall values — they read local getters and will double-shift.
- Existing behaviour on a PH-local device must be byte-identical after this change. Where a test asserts a concrete date, assert the same value the old code produced for a PH device.
- This fixes device **timezone**, not device **clock skew**. A phone whose clock is simply wrong still fails the rules check; that is pre-existing and out of scope.

---

## File Structure

**Mobile — created**
- `lib/core/utils/shop_time.dart` — pure offset math + ambient config. No Firebase, no Flutter.
- `lib/core/utils/shop_timezones.dart` — curated no-DST timezone catalog.
- `lib/domain/entities/shop_timezone_entity.dart` — `ShopTimezoneEntity`.
- `lib/domain/repositories/shop_timezone_repository.dart` — interface.
- `lib/data/models/shop_timezone_model.dart` — Firestore map ↔ entity.
- `lib/data/repositories/shop_timezone_repository_impl.dart` — `settings/general` watch/save.
- `lib/core/utils/shop_time_cache.dart` — SharedPreferences cache so a cold start is already on shop time.
- `lib/presentation/providers/shop_time_provider.dart` — repository/stream/offset/`shopNow` providers.
- `lib/presentation/mobile/screens/settings/shop_timezone_settings_screen.dart` — admin picker.

**Mobile — modified**
- `lib/core/utils/business_day.dart` — business-day vocabulary re-expressed on top of `shop_time.dart`.
- `lib/presentation/providers/business_day_provider.dart` — rollover armed at shop midnight.
- `lib/presentation/providers/unsettled_day_provider.dart` — scan in shop time.
- `lib/data/repositories/sale_repository_impl.dart` — counter key, drawer stamp, `hasCompletedSaleOn`.
- `lib/data/repositories/daily_closing_repository_impl.dart` — `docIdFor`.
- `lib/core/utils/report_date_range.dart` — all 9 presets in shop time.
- `lib/core/extensions/datetime_extensions.dart` — shop-aware day math and comparisons.
- `lib/main.dart` — restore cached offset before `runApp`.
- `lib/config/router/route_names.dart`, `route_guards.dart`, the router file, `settings_screen.dart` — new settings route + tile.

**Web — created**
- `web_admin/src/domain/time/shopTime.ts` — pure offset math + ambient config.
- `web_admin/src/domain/time/shopTimezones.ts` — catalog (mirror of the Dart one).
- `web_admin/src/domain/repositories/ShopTimezoneRepository.ts` — interface.
- `web_admin/src/data/repositories/FirestoreShopTimezoneRepository.ts` — implementation.
- `web_admin/src/presentation/features/settings/TimezoneSettingsPage.tsx` — admin picker.

**Web — modified**
- `web_admin/src/core/utils/businessDay.ts` — `phDayInt` from the configured offset.
- `web_admin/src/domain/reports/dateRange.ts` — presets in shop time.
- `web_admin/src/domain/sales/saleNumber.ts` — `counterKey` in shop time.
- `web_admin/src/domain/hr/payPeriod.ts` — pay periods in shop time.
- `web_admin/src/presentation/features/logs/ActivityLogsPage.tsx` — day grouping in shop time.
- `web_admin/src/presentation/components/common/DateRangePicker.tsx` — custom-range parsing.
- `web_admin/src/infrastructure/di/container.tsx` — repo + ambient bootstrap.
- `web_admin/src/presentation/router/{routePaths.ts,routes.tsx,routeGuards.ts}`, `features/settings/SettingsPage.tsx`.

**Rules / tooling — modified or created**
- `firestore.rules` — `shopOffsetMinutes()`, `phDay()`, `settings/general` validation.
- `tools/firestore-rules-test/test/rules.test.js` — coverage for the above.
- `scripts/seed-shop-timezone.mjs` — one-off seed of `settings/general`.

---

## Task 1: Mobile shop-time core (pure)

**Files:**
- Create: `lib/core/utils/shop_time.dart`
- Create: `lib/core/utils/shop_timezones.dart`
- Test: `test/core/utils/shop_time_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `const int kDefaultShopOffsetMinutes = 480;`
  - `const String kDefaultShopTimezoneId = 'Asia/Manila';`
  - `class ShopTimeConfig { static int offsetMinutes; static String timezoneId; }`
  - `DateTime shopTimeOf(DateTime instant, int offsetMinutes)`
  - `DateTime instantOf(DateTime shopWall, int offsetMinutes)`
  - `int shopDayInt(DateTime instant, int offsetMinutes)`
  - `DateTime shopDateOf(DateTime instant, int offsetMinutes)`
  - `DateTime shopWall(int year, int month, int day, [int hour, int minute, int second, int ms])`
  - `extension ShopTimeX on DateTime { DateTime get inShopTime; DateTime get asShopInstant; }`
  - `class ShopTimezoneOption { final String id; final String label; final int offsetMinutes; }`
  - `const List<ShopTimezoneOption> kShopTimezones;`
  - `ShopTimezoneOption? shopTimezoneById(String id)`

- [ ] **Step 1: Write the failing test**

Create `test/core/utils/shop_time_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/core/utils/shop_timezones.dart';

void main() {
  const ph = 480; // Asia/Manila
  const est = -300; // UTC-5, a "device in the US" stand-in

  group('shopTimeOf', () {
    test('shifts an instant into shop wall time', () {
      final instant = DateTime.utc(2026, 8, 26, 15, 30);
      final wall = shopTimeOf(instant, ph);
      expect(wall.year, 2026);
      expect(wall.month, 8);
      expect(wall.day, 26);
      expect(wall.hour, 23);
      expect(wall.minute, 30);
    });

    test('is independent of the DateTime the caller hands in', () {
      // Same instant expressed two ways must produce the same wall time.
      final utc = DateTime.utc(2026, 8, 26, 15, 30);
      final shifted = utc.add(const Duration(hours: 3)).subtract(const Duration(hours: 3));
      expect(shopTimeOf(shifted, ph), shopTimeOf(utc, ph));
    });

    test('crosses the day boundary at shop midnight, not device midnight', () {
      // 16:00 UTC on the 25th is 00:00 of the 26th in PH.
      final instant = DateTime.utc(2026, 8, 25, 16, 0);
      expect(shopDayInt(instant, ph), 20260826);
      // The same instant is still the 25th for a UTC-5 device.
      expect(shopDayInt(instant, est), 20260825);
    });
  });

  group('instantOf', () {
    test('round-trips with shopTimeOf', () {
      final instant = DateTime.utc(2026, 8, 26, 15, 30, 45, 123);
      expect(instantOf(shopTimeOf(instant, ph), ph), instant);
      expect(instantOf(shopTimeOf(instant, est), est), instant);
    });

    test('returns a UTC instant for a shop wall time', () {
      final wall = shopWall(2026, 8, 26); // shop midnight
      final instant = instantOf(wall, ph);
      expect(instant.isUtc, isTrue);
      expect(instant, DateTime.utc(2026, 8, 25, 16, 0));
    });
  });

  group('shopDayInt', () {
    test('matches the rules yyyymmdd shape', () {
      expect(shopDayInt(DateTime.utc(2026, 1, 2, 4, 0), ph), 20260102);
    });

    test('handles year boundaries', () {
      // 16:00 UTC Dec 31 is 00:00 Jan 1 in PH.
      expect(shopDayInt(DateTime.utc(2026, 12, 31, 16, 0), ph), 20270101);
    });

    test('handles a negative offset', () {
      // 02:00 UTC Jan 1 is 21:00 Dec 31 at UTC-5.
      expect(shopDayInt(DateTime.utc(2027, 1, 1, 2, 0), est), 20261231);
    });
  });

  group('shopDateOf', () {
    test('truncates to shop midnight and stays a wall value', () {
      final d = shopDateOf(DateTime.utc(2026, 8, 26, 15, 30), ph);
      expect(d, shopWall(2026, 8, 26));
      expect(d.isUtc, isTrue);
      expect(d.hour, 0);
    });
  });

  group('ShopTimeConfig + extensions', () {
    setUp(() => ShopTimeConfig.offsetMinutes = kDefaultShopOffsetMinutes);

    test('defaults to Asia/Manila', () {
      expect(ShopTimeConfig.offsetMinutes, 480);
      expect(ShopTimeConfig.timezoneId, 'Asia/Manila');
    });

    test('inShopTime uses the ambient offset', () {
      ShopTimeConfig.offsetMinutes = est;
      expect(DateTime.utc(2026, 8, 26, 15, 30).inShopTime.hour, 10);
    });

    test('asShopInstant inverts inShopTime', () {
      final instant = DateTime.utc(2026, 8, 26, 15, 30);
      expect(instant.inShopTime.asShopInstant, instant);
    });
  });

  group('kShopTimezones', () {
    test('contains Asia/Manila at +480 as the default', () {
      final manila = shopTimezoneById(kDefaultShopTimezoneId);
      expect(manila, isNotNull);
      expect(manila!.offsetMinutes, kDefaultShopOffsetMinutes);
    });

    test('every offset is within the supported range', () {
      for (final tz in kShopTimezones) {
        expect(tz.offsetMinutes, inInclusiveRange(-720, 840));
      }
    });

    test('ids are unique', () {
      final ids = kShopTimezones.map((t) => t.id).toSet();
      expect(ids.length, kShopTimezones.length);
    });

    test('unknown id returns null', () {
      expect(shopTimezoneById('Mars/Olympus'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/shop_time_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:maki_mobile_pos/core/utils/shop_time.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/core/utils/shop_time.dart`:

```dart
/// Shop-timezone helpers.
///
/// The shop runs on one configured timezone (`settings/general`, default
/// Asia/Manila UTC+8). Every calendar computation — "what day is it",
/// range boundaries, day grouping, display — must happen in that zone
/// rather than the device's. A phone set to another timezone otherwise
/// computes the wrong business day, and its `drawer_state` write is
/// rejected by the security rules: a hard sale failure, not a cosmetic bug.
///
/// Two representations, kept strictly apart:
///
/// * **instant** — a real point in time. What Firestore stores and what
///   `Timestamp.toDate()` returns. Never shifted before writing.
/// * **shop wall time** — an instant shifted by the shop offset so its
///   *fields* (`year`/`month`/`day`/`hour`) read shop-local. Produced by
///   [shopTimeOf]; always `isUtc` so field access is device-independent.
///   For day math and display ONLY — never write one to Firestore. Convert
///   back with [instantOf] before building a query bound or a `Timestamp`.
///
/// Only fixed-offset (no-DST) zones are supported, so plain offset
/// arithmetic is exact — see `shop_timezones.dart`.
library;

/// Asia/Manila — UTC+8, no DST. The system default everywhere.
const int kDefaultShopOffsetMinutes = 480;
const String kDefaultShopTimezoneId = 'Asia/Manila';

/// Ambient shop timezone, for code that cannot reach a Riverpod `ref`
/// (extension getters, formatting helpers). Set once at startup from the
/// cached value and again whenever `settings/general` changes — the same
/// pattern as `Intl.defaultLocale`. Riverpod code should prefer
/// `shopOffsetProvider` / `shopNowProvider` so tests can override it
/// without touching global state.
class ShopTimeConfig {
  ShopTimeConfig._();

  static int offsetMinutes = kDefaultShopOffsetMinutes;
  static String timezoneId = kDefaultShopTimezoneId;

  static void apply({required String timezoneId, required int offsetMinutes}) {
    ShopTimeConfig.timezoneId = timezoneId;
    ShopTimeConfig.offsetMinutes = offsetMinutes;
  }
}

/// Shop wall-clock view of [instant]. Its fields read shop-local. Do not persist.
DateTime shopTimeOf(DateTime instant, int offsetMinutes) =>
    instant.toUtc().add(Duration(minutes: offsetMinutes));

/// The real instant for a shop wall-clock time — inverse of [shopTimeOf].
DateTime instantOf(DateTime shopWallTime, int offsetMinutes) => DateTime.utc(
      shopWallTime.year,
      shopWallTime.month,
      shopWallTime.day,
      shopWallTime.hour,
      shopWallTime.minute,
      shopWallTime.second,
      shopWallTime.millisecond,
    ).subtract(Duration(minutes: offsetMinutes));

/// Builds a shop wall-clock value from calendar fields.
DateTime shopWall(
  int year, [
  int month = 1,
  int day = 1,
  int hour = 0,
  int minute = 0,
  int second = 0,
  int millisecond = 0,
]) =>
    DateTime.utc(year, month, day, hour, minute, second, millisecond);

/// yyyymmdd int for [instant] in shop time. Must equal the rules' `phDay()`
/// for the same instant — the `drawer_state` write depends on it.
int shopDayInt(DateTime instant, int offsetMinutes) {
  final w = shopTimeOf(instant, offsetMinutes);
  return w.year * 10000 + w.month * 100 + w.day;
}

/// Shop midnight (a wall value) of the day containing [instant].
DateTime shopDateOf(DateTime instant, int offsetMinutes) {
  final w = shopTimeOf(instant, offsetMinutes);
  return shopWall(w.year, w.month, w.day);
}

/// Ambient-offset conveniences for display and comparison code.
extension ShopTimeX on DateTime {
  /// Shop wall-clock view using the ambient offset. Display/day math only.
  DateTime get inShopTime => shopTimeOf(this, ShopTimeConfig.offsetMinutes);

  /// Treats this as a shop wall-clock value and returns the real instant.
  DateTime get asShopInstant => instantOf(this, ShopTimeConfig.offsetMinutes);
}
```

Create `lib/core/utils/shop_timezones.dart`:

```dart
import 'package:maki_mobile_pos/core/utils/shop_time.dart';

/// One selectable shop timezone.
///
/// Only fixed-offset (no-DST) zones are listed: the offset is stored in
/// `settings/general.tzOffsetMinutes` and read by the Firestore rules,
/// which have no timezone database and cannot follow a DST transition.
class ShopTimezoneOption {
  final String id; // IANA name, e.g. 'Asia/Manila'
  final String label; // What the picker shows
  final int offsetMinutes;

  const ShopTimezoneOption({
    required this.id,
    required this.label,
    required this.offsetMinutes,
  });
}

/// Curated catalog. MIRRORED in web_admin/src/domain/time/shopTimezones.ts —
/// keep ids and offsets in lock-step across both surfaces.
const List<ShopTimezoneOption> kShopTimezones = [
  ShopTimezoneOption(id: 'Asia/Manila', label: 'Philippines (Manila)', offsetMinutes: 480),
  ShopTimezoneOption(id: 'Asia/Singapore', label: 'Singapore', offsetMinutes: 480),
  ShopTimezoneOption(id: 'Asia/Hong_Kong', label: 'Hong Kong', offsetMinutes: 480),
  ShopTimezoneOption(id: 'Asia/Shanghai', label: 'China (Shanghai)', offsetMinutes: 480),
  ShopTimezoneOption(id: 'Asia/Kuala_Lumpur', label: 'Malaysia (Kuala Lumpur)', offsetMinutes: 480),
  ShopTimezoneOption(id: 'Asia/Tokyo', label: 'Japan (Tokyo)', offsetMinutes: 540),
  ShopTimezoneOption(id: 'Asia/Seoul', label: 'South Korea (Seoul)', offsetMinutes: 540),
  ShopTimezoneOption(id: 'Asia/Bangkok', label: 'Thailand (Bangkok)', offsetMinutes: 420),
  ShopTimezoneOption(id: 'Asia/Jakarta', label: 'Indonesia (Jakarta)', offsetMinutes: 420),
  ShopTimezoneOption(id: 'Asia/Ho_Chi_Minh', label: 'Vietnam (Ho Chi Minh)', offsetMinutes: 420),
  ShopTimezoneOption(id: 'Asia/Kolkata', label: 'India (Kolkata)', offsetMinutes: 330),
  ShopTimezoneOption(id: 'Asia/Dubai', label: 'UAE (Dubai)', offsetMinutes: 240),
  ShopTimezoneOption(id: 'Australia/Brisbane', label: 'Australia (Brisbane)', offsetMinutes: 600),
  ShopTimezoneOption(id: 'Pacific/Guam', label: 'Guam', offsetMinutes: 600),
  ShopTimezoneOption(id: 'UTC', label: 'UTC', offsetMinutes: 0),
];

/// The catalog entry for [id], or null when the stored id is unknown
/// (e.g. written by a newer client). Callers fall back to the stored
/// offset, never to the device zone.
ShopTimezoneOption? shopTimezoneById(String id) {
  for (final tz in kShopTimezones) {
    if (tz.id == id) return tz;
  }
  return null;
}

/// '+08:00' / '-05:00' — for the picker subtitle.
String formatOffset(int offsetMinutes) {
  final sign = offsetMinutes < 0 ? '-' : '+';
  final abs = offsetMinutes.abs();
  final h = (abs ~/ 60).toString().padLeft(2, '0');
  final m = (abs % 60).toString().padLeft(2, '0');
  return '$sign$h:$m';
}

/// The default option, guaranteed present.
ShopTimezoneOption get defaultShopTimezone =>
    shopTimezoneById(kDefaultShopTimezoneId)!;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/utils/shop_time_test.dart`
Expected: PASS (all groups).

Then: `flutter analyze lib/core/utils/shop_time.dart lib/core/utils/shop_timezones.dart`
Expected: "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/shop_time.dart lib/core/utils/shop_timezones.dart test/core/utils/shop_time_test.dart
git commit -m "feat(timezone): shop-time core — offset math, ambient config, zone catalog"
```

---

## Task 2: Mobile `settings/general` entity, model, repository

**Files:**
- Create: `lib/domain/entities/shop_timezone_entity.dart`
- Create: `lib/domain/repositories/shop_timezone_repository.dart`
- Create: `lib/data/models/shop_timezone_model.dart`
- Create: `lib/data/repositories/shop_timezone_repository_impl.dart`
- Modify: `lib/domain/entities/entities.dart` (barrel export), `lib/data/models/models.dart` (barrel export)
- Test: `test/data/models/shop_timezone_model_test.dart`

**Interfaces:**
- Consumes: `kDefaultShopOffsetMinutes`, `kDefaultShopTimezoneId` (Task 1); `FirestoreCollections.settings`, `FirestoreCollections.generalSettings` (existing).
- Produces:
  - `class ShopTimezoneEntity { final String timezoneId; final int offsetMinutes; static const defaults; ShopTimezoneEntity copyWith({...}); }`
  - `abstract class ShopTimezoneRepository { Stream<ShopTimezoneEntity> watch(); Future<ShopTimezoneEntity> get(); Future<void> save(ShopTimezoneEntity settings, {required String updatedBy}); }`
  - `class ShopTimezoneModel { factory ShopTimezoneModel.fromMap(Map<String,dynamic>? map); factory ShopTimezoneModel.fromEntity(ShopTimezoneEntity e); Map<String,dynamic> toMap({required String updatedBy}); ShopTimezoneEntity toEntity(); }`
  - `class ShopTimezoneRepositoryImpl implements ShopTimezoneRepository`

- [ ] **Step 1: Write the failing test**

Create `test/data/models/shop_timezone_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/shop_timezone_model.dart';
import 'package:maki_mobile_pos/domain/entities/shop_timezone_entity.dart';

void main() {
  group('ShopTimezoneEntity.defaults', () {
    test('is Asia/Manila at +480', () {
      expect(ShopTimezoneEntity.defaults.timezoneId, 'Asia/Manila');
      expect(ShopTimezoneEntity.defaults.offsetMinutes, 480);
    });
  });

  group('ShopTimezoneModel.fromMap', () {
    test('a missing doc reads as the defaults', () {
      expect(ShopTimezoneModel.fromMap(null).toEntity(), ShopTimezoneEntity.defaults);
    });

    test('an empty doc reads as the defaults', () {
      expect(ShopTimezoneModel.fromMap(const {}).toEntity(), ShopTimezoneEntity.defaults);
    });

    test('reads a stored timezone', () {
      final e = ShopTimezoneModel.fromMap(const {
        'timezoneId': 'Asia/Tokyo',
        'tzOffsetMinutes': 540,
      }).toEntity();
      expect(e.timezoneId, 'Asia/Tokyo');
      expect(e.offsetMinutes, 540);
    });

    test('ignores unrelated keys in the shared general doc', () {
      final e = ShopTimezoneModel.fromMap(const {
        'timezoneId': 'Asia/Dubai',
        'tzOffsetMinutes': 240,
        'someOtherGeneralSetting': true,
      }).toEntity();
      expect(e.offsetMinutes, 240);
    });

    test('falls back to the default offset when the value is out of range', () {
      final e = ShopTimezoneModel.fromMap(const {
        'timezoneId': 'Bad/Zone',
        'tzOffsetMinutes': 99999,
      }).toEntity();
      expect(e.offsetMinutes, 480);
    });

    test('falls back to the default offset when the value is not an int', () {
      final e = ShopTimezoneModel.fromMap(const {
        'timezoneId': 'Asia/Manila',
        'tzOffsetMinutes': 'eight',
      }).toEntity();
      expect(e.offsetMinutes, 480);
    });
  });

  group('ShopTimezoneModel.toMap', () {
    test('writes both fields plus audit keys', () {
      final map = ShopTimezoneModel.fromEntity(
        const ShopTimezoneEntity(timezoneId: 'Asia/Tokyo', offsetMinutes: 540),
      ).toMap(updatedBy: 'uid-1');
      expect(map['timezoneId'], 'Asia/Tokyo');
      expect(map['tzOffsetMinutes'], 540);
      expect(map['updatedBy'], 'uid-1');
      expect(map.containsKey('updatedAt'), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/models/shop_timezone_model_test.dart`
Expected: FAIL — URIs don't exist.

- [ ] **Step 3: Write the implementation**

Create `lib/domain/entities/shop_timezone_entity.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';

/// The shop-wide timezone (the `timezoneId` / `tzOffsetMinutes` keys of the
/// shared `settings/general` doc). A missing doc reads as [defaults], which
/// is also what the Firestore rules fall back to — so an unseeded database
/// behaves exactly like the pre-feature system.
class ShopTimezoneEntity extends Equatable {
  /// IANA name, for display and for the picker.
  final String timezoneId;

  /// Minutes east of UTC. The value all day math and the rules use.
  final int offsetMinutes;

  const ShopTimezoneEntity({
    required this.timezoneId,
    required this.offsetMinutes,
  });

  static const defaults = ShopTimezoneEntity(
    timezoneId: kDefaultShopTimezoneId,
    offsetMinutes: kDefaultShopOffsetMinutes,
  );

  ShopTimezoneEntity copyWith({String? timezoneId, int? offsetMinutes}) =>
      ShopTimezoneEntity(
        timezoneId: timezoneId ?? this.timezoneId,
        offsetMinutes: offsetMinutes ?? this.offsetMinutes,
      );

  @override
  List<Object?> get props => [timezoneId, offsetMinutes];
}
```

Create `lib/data/models/shop_timezone_model.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/shop_timezone_entity.dart';

/// Firestore mapping for the timezone keys of `settings/general`.
///
/// Reads are defensive: a missing doc, a missing key, a non-int value, or an
/// out-of-range offset all fall back to the default rather than throwing.
/// Getting this wrong would break the business day on every device, so the
/// safest possible value wins.
class ShopTimezoneModel {
  static const int _minOffset = -720;
  static const int _maxOffset = 840;

  final String timezoneId;
  final int offsetMinutes;

  const ShopTimezoneModel({
    required this.timezoneId,
    required this.offsetMinutes,
  });

  factory ShopTimezoneModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return _defaults;

    final rawId = map['timezoneId'];
    final rawOffset = map['tzOffsetMinutes'];

    final offset = rawOffset is int && rawOffset >= _minOffset && rawOffset <= _maxOffset
        ? rawOffset
        : ShopTimezoneEntity.defaults.offsetMinutes;
    final id = rawId is String && rawId.isNotEmpty
        ? rawId
        : ShopTimezoneEntity.defaults.timezoneId;

    return ShopTimezoneModel(timezoneId: id, offsetMinutes: offset);
  }

  factory ShopTimezoneModel.fromEntity(ShopTimezoneEntity e) =>
      ShopTimezoneModel(timezoneId: e.timezoneId, offsetMinutes: e.offsetMinutes);

  static ShopTimezoneModel get _defaults =>
      ShopTimezoneModel.fromEntity(ShopTimezoneEntity.defaults);

  /// Merge payload — `settings/general` is a shared bucket for future general
  /// settings, so this writes only the timezone keys plus audit fields.
  Map<String, dynamic> toMap({required String updatedBy}) => {
        'timezoneId': timezoneId,
        'tzOffsetMinutes': offsetMinutes,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      };

  ShopTimezoneEntity toEntity() =>
      ShopTimezoneEntity(timezoneId: timezoneId, offsetMinutes: offsetMinutes);
}
```

Create `lib/domain/repositories/shop_timezone_repository.dart`:

```dart
import 'package:maki_mobile_pos/domain/entities/shop_timezone_entity.dart';

/// The timezone keys of the shared `settings/general` doc.
///
/// [watch] is a live stream because a timezone change has to reach every
/// open screen — a stale offset means a wrong business day. A missing doc
/// emits [ShopTimezoneEntity.defaults].
abstract class ShopTimezoneRepository {
  Stream<ShopTimezoneEntity> watch();

  Future<ShopTimezoneEntity> get();

  Future<void> save(ShopTimezoneEntity settings, {required String updatedBy});
}
```

Create `lib/data/repositories/shop_timezone_repository_impl.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/shop_timezone_model.dart';
import 'package:maki_mobile_pos/domain/entities/shop_timezone_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/shop_timezone_repository.dart';

/// Firestore implementation over `settings/general`, the doc shared with the
/// web admin. Saves merge rather than overwrite: `general` is a bucket for
/// other future settings, unlike `settings/hr` which is a full overwrite.
class ShopTimezoneRepositoryImpl implements ShopTimezoneRepository {
  final FirebaseFirestore _firestore;

  ShopTimezoneRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc => _firestore
      .collection(FirestoreCollections.settings)
      .doc(FirestoreCollections.generalSettings);

  @override
  Stream<ShopTimezoneEntity> watch() => _doc
      .snapshots()
      .map((snap) => ShopTimezoneModel.fromMap(snap.data()).toEntity());

  @override
  Future<ShopTimezoneEntity> get() async {
    try {
      final snap = await _doc.get();
      return ShopTimezoneModel.fromMap(snap.data()).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to load shop timezone: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> save(ShopTimezoneEntity settings, {required String updatedBy}) async {
    try {
      await _doc.set(
        ShopTimezoneModel.fromEntity(settings).toMap(updatedBy: updatedBy),
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to save shop timezone: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
}
```

Add the barrel exports — append to `lib/domain/entities/entities.dart`:

```dart
export 'shop_timezone_entity.dart';
```

and to `lib/data/models/models.dart`:

```dart
export 'shop_timezone_model.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/models/shop_timezone_model_test.dart`
Expected: PASS.

Run: `flutter analyze lib/domain/entities/shop_timezone_entity.dart lib/data/models/shop_timezone_model.dart lib/data/repositories/shop_timezone_repository_impl.dart lib/domain/repositories/shop_timezone_repository.dart`
Expected: "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/shop_timezone_entity.dart lib/domain/repositories/shop_timezone_repository.dart lib/data/models/shop_timezone_model.dart lib/data/repositories/shop_timezone_repository_impl.dart lib/domain/entities/entities.dart lib/data/models/models.dart test/data/models/shop_timezone_model_test.dart
git commit -m "feat(timezone): settings/general timezone entity, model and repository"
```

---

## Task 3: Mobile providers + cold-start cache

**Files:**
- Create: `lib/core/utils/shop_time_cache.dart`
- Create: `lib/presentation/providers/shop_time_provider.dart`
- Modify: `lib/main.dart`
- Test: `test/presentation/providers/shop_time_provider_test.dart`

**Interfaces:**
- Consumes: `ShopTimeConfig`, `shopTimeOf` (Task 1); `ShopTimezoneRepository`, `ShopTimezoneEntity` (Task 2); `nowProvider` from `lib/presentation/providers/business_day_provider.dart` (existing).
- Produces:
  - `class ShopTimeCache { static Future<void> restore(); static Future<void> save(ShopTimezoneEntity tz); }`
  - `final shopTimezoneRepositoryProvider = Provider<ShopTimezoneRepository>`
  - `final shopTimezoneProvider = StreamProvider<ShopTimezoneEntity>`
  - `final shopOffsetProvider = Provider<int>`
  - `final shopNowProvider = Provider<DateTime Function()>` — returns shop **wall** time
  - `final shopInstantNowProvider = Provider<DateTime Function()>` — returns the raw instant

- [ ] **Step 1: Write the failing test**

Create `test/presentation/providers/shop_time_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/domain/entities/shop_timezone_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/shop_timezone_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/business_day_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/shop_time_provider.dart';

class _FakeRepo implements ShopTimezoneRepository {
  _FakeRepo(this.controller);
  final Stream<ShopTimezoneEntity> controller;

  @override
  Stream<ShopTimezoneEntity> watch() => controller;

  @override
  Future<ShopTimezoneEntity> get() async => ShopTimezoneEntity.defaults;

  @override
  Future<void> save(ShopTimezoneEntity settings, {required String updatedBy}) async {}
}

void main() {
  setUp(() {
    ShopTimeConfig.apply(
      timezoneId: kDefaultShopTimezoneId,
      offsetMinutes: kDefaultShopOffsetMinutes,
    );
  });

  ProviderContainer containerWith(
    Stream<ShopTimezoneEntity> stream, {
    DateTime? fixedNow,
  }) {
    return ProviderContainer(
      overrides: [
        shopTimezoneRepositoryProvider.overrideWithValue(_FakeRepo(stream)),
        if (fixedNow != null) nowProvider.overrideWithValue(() => fixedNow),
      ],
    );
  }

  test('shopOffsetProvider falls back to the default before data arrives', () {
    final c = containerWith(const Stream<ShopTimezoneEntity>.empty());
    addTearDown(c.dispose);
    expect(c.read(shopOffsetProvider), 480);
  });

  test('shopOffsetProvider reflects the stored timezone', () async {
    final c = containerWith(
      Stream.value(const ShopTimezoneEntity(timezoneId: 'Asia/Tokyo', offsetMinutes: 540)),
    );
    addTearDown(c.dispose);
    await c.read(shopTimezoneProvider.future);
    expect(c.read(shopOffsetProvider), 540);
  });

  test('a stored timezone updates the ambient config', () async {
    final c = containerWith(
      Stream.value(const ShopTimezoneEntity(timezoneId: 'Asia/Tokyo', offsetMinutes: 540)),
    );
    addTearDown(c.dispose);
    await c.read(shopTimezoneProvider.future);
    expect(ShopTimeConfig.offsetMinutes, 540);
    expect(ShopTimeConfig.timezoneId, 'Asia/Tokyo');
  });

  test('shopNowProvider returns shop wall time, not the device instant', () async {
    final instant = DateTime.utc(2026, 8, 26, 15, 30);
    final c = containerWith(
      Stream.value(const ShopTimezoneEntity(timezoneId: 'Asia/Manila', offsetMinutes: 480)),
      fixedNow: instant,
    );
    addTearDown(c.dispose);
    await c.read(shopTimezoneProvider.future);

    final wall = c.read(shopNowProvider)();
    expect(wall.day, 26);
    expect(wall.hour, 23);
    expect(c.read(shopInstantNowProvider)(), instant);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/providers/shop_time_provider_test.dart`
Expected: FAIL — `shop_time_provider.dart` doesn't exist.

- [ ] **Step 3: Write the implementation**

Create `lib/core/utils/shop_time_cache.dart`:

```dart
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/domain/entities/shop_timezone_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Last-known shop timezone, persisted so a cold start (especially an
/// offline one) is already on shop time before the Firestore stream
/// delivers its first snapshot. Without this the first frames would compute
/// "today" from the default, which is wrong for a shop that changed zones.
class ShopTimeCache {
  ShopTimeCache._();

  static const _idKey = 'shop_timezone_id';
  static const _offsetKey = 'shop_timezone_offset_minutes';

  /// Applies the cached timezone to [ShopTimeConfig]. Never throws —
  /// a failure here must not block app startup.
  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_idKey);
      final offset = prefs.getInt(_offsetKey);
      if (id != null && offset != null) {
        ShopTimeConfig.apply(timezoneId: id, offsetMinutes: offset);
      }
    } catch (_) {
      // Keep the default; the Firestore stream corrects it shortly.
    }
  }

  static Future<void> save(ShopTimezoneEntity tz) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_idKey, tz.timezoneId);
      await prefs.setInt(_offsetKey, tz.offsetMinutes);
    } catch (_) {
      // Caching is best-effort.
    }
  }
}
```

Create `lib/presentation/providers/shop_time_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/core/utils/shop_time_cache.dart';
import 'package:maki_mobile_pos/data/repositories/shop_timezone_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/shop_timezone_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/shop_timezone_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/business_day_provider.dart';

final shopTimezoneRepositoryProvider = Provider<ShopTimezoneRepository>(
  (ref) => ShopTimezoneRepositoryImpl(),
);

/// Live shop timezone. Applying it to [ShopTimeConfig] here (rather than in
/// a widget) means extension getters and formatting helpers — which have no
/// `ref` — see the change at the same moment provider consumers do.
final shopTimezoneProvider = StreamProvider<ShopTimezoneEntity>((ref) {
  return ref.watch(shopTimezoneRepositoryProvider).watch().map((tz) {
    ShopTimeConfig.apply(
      timezoneId: tz.timezoneId,
      offsetMinutes: tz.offsetMinutes,
    );
    ShopTimeCache.save(tz);
    return tz;
  });
});

/// Offset in minutes east of UTC. Falls back to the ambient value (cache or
/// default) while the stream is loading or if it errors — never to the
/// device zone.
final shopOffsetProvider = Provider<int>((ref) {
  return ref.watch(shopTimezoneProvider).maybeWhen(
        data: (tz) => tz.offsetMinutes,
        orElse: () => ShopTimeConfig.offsetMinutes,
      );
});

/// "Now" as a shop **wall-clock** value — for day math and display.
/// Never persist its result; use [shopInstantNowProvider] for writes.
final shopNowProvider = Provider<DateTime Function()>((ref) {
  final now = ref.watch(nowProvider);
  final offset = ref.watch(shopOffsetProvider);
  return () => shopTimeOf(now(), offset);
});

/// "Now" as a real instant — for `createdAt` and query bounds.
final shopInstantNowProvider = Provider<DateTime Function()>((ref) {
  return ref.watch(nowProvider);
});
```

Modify `lib/main.dart` — restore the cache before `runApp` so the first frame is already on shop time. Insert immediately after the Firebase init `try/catch` block and before `runApp(`:

```dart
  // Apply the last-known shop timezone before the first frame. The Firestore
  // stream (shopTimezoneProvider) corrects it moments later; without this a
  // cold or offline start would compute "today" from the default.
  await ShopTimeCache.restore();
```

and add the import at the top of `lib/main.dart`:

```dart
import 'package:maki_mobile_pos/core/utils/shop_time_cache.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/presentation/providers/shop_time_provider_test.dart`
Expected: PASS.

Run: `flutter analyze lib/presentation/providers/shop_time_provider.dart lib/core/utils/shop_time_cache.dart lib/main.dart`
Expected: "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/shop_time_cache.dart lib/presentation/providers/shop_time_provider.dart lib/main.dart test/presentation/providers/shop_time_provider_test.dart
git commit -m "feat(timezone): shop timezone providers + cold-start cache"
```

---

## Task 4: Mobile business-day rollover in shop time

**Files:**
- Modify: `lib/core/utils/business_day.dart`
- Modify: `lib/presentation/providers/business_day_provider.dart`
- Modify: `lib/presentation/providers/unsettled_day_provider.dart`
- Test: `test/core/utils/business_day_test.dart` (rewrite)

**Interfaces:**
- Consumes: `shopTimeOf`, `instantOf`, `shopWall`, `shopDayInt`, `shopDateOf` (Task 1); `shopOffsetProvider`, `shopNowProvider` (Task 3).
- Produces:
  - `DateTime nextShopMidnightAfter(DateTime instant, int offsetMinutes)` — returns a real **instant**
  - `DateTime businessDateOf(DateTime instant, int offsetMinutes)` — returns a shop **wall** midnight
  - `int businessDayInt(DateTime instant, int offsetMinutes)`
  - `int businessDayIntOfWall(DateTime shopWallDate)`
  - `DateTime dateFromBusinessDayInt(int yyyymmdd)` — returns a shop **wall** midnight
  - `businessDayProvider` now holds a shop **wall** midnight `DateTime`.

**Migration note for the implementer:** `businessDayInt` and `businessDateOf` change from one argument to two. That is deliberate — the compiler will point at every call site so none is missed. Sites that already hold a shop wall value (not an instant) use `businessDayIntOfWall` instead.

- [ ] **Step 1: Write the failing test**

Replace the contents of `test/core/utils/business_day_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/business_day.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';

void main() {
  const ph = 480;
  const est = -300;

  group('nextShopMidnightAfter', () {
    test('returns the instant of the next shop midnight', () {
      // 2026-07-24 13:45 PH == 05:45 UTC. Next shop midnight is
      // 2026-07-25 00:00 PH == 2026-07-24 16:00 UTC.
      final instant = DateTime.utc(2026, 7, 24, 5, 45);
      expect(nextShopMidnightAfter(instant, ph), DateTime.utc(2026, 7, 24, 16, 0));
    });

    test('one second before shop midnight rolls within a second', () {
      final instant = DateTime.utc(2026, 7, 24, 15, 59, 59);
      final next = nextShopMidnightAfter(instant, ph);
      expect(next.difference(instant), const Duration(seconds: 1));
    });

    test('crosses a month boundary', () {
      // 2026-07-31 22:00 PH == 14:00 UTC → next shop midnight is Aug 1 PH.
      final instant = DateTime.utc(2026, 7, 31, 14, 0);
      expect(businessDayInt(nextShopMidnightAfter(instant, ph), ph), 20260801);
    });

    test('crosses a year boundary', () {
      final instant = DateTime.utc(2026, 12, 31, 15, 0); // 23:00 PH Dec 31
      expect(businessDayInt(nextShopMidnightAfter(instant, ph), ph), 20270101);
    });

    test('honours a negative offset', () {
      // 2026-07-24 20:00 UTC == 15:00 at UTC-5 → next midnight is Jul 25 local
      // == 2026-07-25 05:00 UTC.
      final instant = DateTime.utc(2026, 7, 24, 20, 0);
      expect(nextShopMidnightAfter(instant, est), DateTime.utc(2026, 7, 25, 5, 0));
    });
  });

  group('businessDateOf', () {
    test('truncates to shop midnight as a wall value', () {
      final instant = DateTime.utc(2026, 7, 24, 5, 45, 30, 500);
      expect(businessDateOf(instant, ph), shopWall(2026, 7, 24));
    });

    test('an instant just before shop midnight still belongs to that day', () {
      final instant = DateTime.utc(2026, 7, 24, 15, 59, 59); // 23:59:59 PH
      expect(businessDateOf(instant, ph), shopWall(2026, 7, 24));
    });

    test('an instant just after shop midnight belongs to the next day', () {
      final instant = DateTime.utc(2026, 7, 24, 16, 0, 1); // 00:00:01 PH Jul 25
      expect(businessDateOf(instant, ph), shopWall(2026, 7, 25));
    });
  });

  group('businessDayInt', () {
    test('produces yyyymmdd', () {
      expect(businessDayInt(DateTime.utc(2026, 7, 24, 5, 0), ph), 20260724);
    });

    test('the same instant differs by zone — this is the bug being fixed', () {
      final instant = DateTime.utc(2026, 7, 24, 16, 30); // 00:30 Jul 25 PH
      expect(businessDayInt(instant, ph), 20260725);
      expect(businessDayInt(instant, est), 20260724);
    });
  });

  group('businessDayIntOfWall', () {
    test('reads the fields of an already-shop-wall date', () {
      expect(businessDayIntOfWall(shopWall(2026, 7, 24)), 20260724);
    });
  });

  group('dateFromBusinessDayInt', () {
    test('round-trips with businessDayIntOfWall', () {
      expect(businessDayIntOfWall(dateFromBusinessDayInt(20260724)), 20260724);
    });

    test('returns a shop wall midnight', () {
      expect(dateFromBusinessDayInt(20260724), shopWall(2026, 7, 24));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/business_day_test.dart`
Expected: FAIL — `nextShopMidnightAfter` undefined, and `businessDayInt` called with 2 args.

- [ ] **Step 3: Write the implementation**

Replace the contents of `lib/core/utils/business_day.dart`:

```dart
/// Business-day boundary helpers.
///
/// The business day is defined by the shop's configured timezone
/// (`settings/general`, default Asia/Manila UTC+8) — NOT by the device's.
/// A device in another zone would otherwise compute the wrong day and its
/// `drawer_state` write would be rejected by the security rules, failing
/// the sale outright.
///
/// These are pure (offset passed explicitly) so they're unit-testable
/// without a clock or a provider. See `shop_time.dart` for the
/// instant-vs-wall distinction these build on.
library;

import 'package:maki_mobile_pos/core/utils/shop_time.dart';

/// The real **instant** of the next shop midnight strictly after [instant].
/// Returned as an instant so a `Timer` duration is a plain subtraction.
DateTime nextShopMidnightAfter(DateTime instant, int offsetMinutes) {
  final w = shopTimeOf(instant, offsetMinutes);
  return instantOf(shopWall(w.year, w.month, w.day + 1), offsetMinutes);
}

/// Shop midnight (a **wall** value) of the business day containing [instant].
DateTime businessDateOf(DateTime instant, int offsetMinutes) =>
    shopDateOf(instant, offsetMinutes);

/// yyyymmdd int for the `drawer_state` doc. Must equal the rules' `phDay()`
/// for the same instant.
int businessDayInt(DateTime instant, int offsetMinutes) =>
    shopDayInt(instant, offsetMinutes);

/// yyyymmdd for a value that is ALREADY shop wall time (e.g. the
/// `businessDayProvider` state). No shifting — shifting twice would be a
/// silent off-by-one.
int businessDayIntOfWall(DateTime shopWallDate) =>
    shopWallDate.year * 10000 + shopWallDate.month * 100 + shopWallDate.day;

/// Inverse of [businessDayIntOfWall] — a shop **wall** midnight.
DateTime dateFromBusinessDayInt(int yyyymmdd) => shopWall(
      yyyymmdd ~/ 10000,
      (yyyymmdd ~/ 100) % 100,
      yyyymmdd % 100,
    );
```

Replace the contents of `lib/presentation/providers/business_day_provider.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/utils/business_day.dart';
import 'package:maki_mobile_pos/presentation/providers/shop_time_provider.dart';

/// Injectable clock (override in tests). Returns a real instant — shop-time
/// conversion happens downstream, so nothing here depends on the device zone.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The current business day as a **shop wall-clock** midnight, used as the
/// single source of "today" across the app.
///
/// Rolls over on a timer armed for the next SHOP midnight, and can be
/// force-rechecked (e.g. from an app-lifecycle resume hook) to catch the
/// case where the device was asleep and missed the timer firing exactly at
/// midnight. Re-arms whenever the shop timezone changes, so switching zones
/// in settings takes effect without a restart.
class BusinessDayNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    // Watching the offset rebuilds this notifier when the shop timezone
    // changes — the day and the pending rollover both need recomputing.
    final offset = ref.watch(shopOffsetProvider);
    final now = ref.read(nowProvider)();
    _arm(now, offset);
    ref.onDispose(() => _timer?.cancel());
    return businessDateOf(now, offset);
  }

  void _arm(DateTime now, int offset) {
    _timer?.cancel();
    _timer = Timer(
      nextShopMidnightAfter(now, offset).difference(now) +
          const Duration(seconds: 1),
      _tick,
    );
  }

  void _tick() {
    final offset = ref.read(shopOffsetProvider);
    final now = ref.read(nowProvider)();
    final day = businessDateOf(now, offset);
    if (day != state) state = day;
    _arm(now, offset);
  }

  /// Called from the app-lifecycle observer on resume.
  void recheck() => _tick();
}

final businessDayProvider =
    NotifierProvider<BusinessDayNotifier, DateTime>(BusinessDayNotifier.new);
```

In `lib/presentation/providers/unsettled_day_provider.dart`, `today` is now a shop wall midnight, so day arithmetic on it is safe (UTC has no DST). Change only the `businessDayInt(today)` call, which receives an already-wall value:

```dart
  if (lastSaleDay > 0 &&
      lastSaleDay < businessDayIntOfWall(today) &&
      lastSaleDay > lastClosedDay) {
    return dateFromBusinessDayInt(lastSaleDay);
  }
```

Also normalise the closing anchor so a stored `businessDate` instant becomes a wall value before the loop. Replace lines 28–33 with:

```dart
  final offset = ref.watch(shopOffsetProvider);
  final latest = await closingRepo.latestClosing();
  var start = latest == null
      ? today.subtract(const Duration(days: 14))
      : businessDateOf(latest.businessDate, offset)
          .add(const Duration(days: 1));
  final floor = today.subtract(const Duration(days: 14));
  if (start.isBefore(floor)) start = floor; // 14-day scan cap
```

and add the import:

```dart
import 'package:maki_mobile_pos/presentation/providers/shop_time_provider.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/utils/business_day_test.dart`
Expected: PASS.

Run: `flutter analyze`
Expected: errors ONLY in the not-yet-migrated call sites of `businessDayInt` / `businessDateOf` (Task 5 handles them). Record the list — it is the Task 5 worklist. If any file outside `sale_repository_impl.dart`, `daily_closing_repository_impl.dart`, `close_day_usecase.dart`, `get_daily_closing_summary_usecase.dart` appears, migrate it here using the same instant-vs-wall rule.

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/business_day.dart lib/presentation/providers/business_day_provider.dart lib/presentation/providers/unsettled_day_provider.dart test/core/utils/business_day_test.dart
git commit -m "feat(timezone): business-day rollover follows the shop timezone"
```

---

## Task 5: Mobile sale + closing writes in shop time

**Files:**
- Modify: `lib/data/repositories/sale_repository_impl.dart` (`_getDateKey`, the `drawer_state` stamp, `hasCompletedSaleOn`)
- Modify: `lib/data/repositories/daily_closing_repository_impl.dart` (`docIdFor`)
- Modify: any remaining call sites `flutter analyze` reported in Task 4 (e.g. `close_day_usecase.dart`, `get_daily_closing_summary_usecase.dart`)
- Test: `test/data/repositories/shop_time_keys_test.dart`

**Interfaces:**
- Consumes: `shopDayInt`, `shopTimeOf`, `instantOf`, `shopWall` (Task 1); `businessDayInt`, `businessDayIntOfWall` (Task 4).
- Produces:
  - `SaleRepositoryImpl.dateKeyFor(DateTime instant, int offsetMinutes)` — static, testable, `YYYYMMDD`
  - `DailyClosingRepositoryImpl.docIdFor(DateTime shopWallDate)` — takes a shop **wall** date
  - `SaleRepository.hasCompletedSaleOn(DateTime shopWallDate)` — contract change: the argument is a shop wall date

**Wiring note:** these repositories are constructed without Riverpod, so they take the offset explicitly. Add an `int Function() offsetMinutes` constructor parameter defaulting to `() => ShopTimeConfig.offsetMinutes`, and let the providers pass `() => ref.read(shopOffsetProvider)`. This keeps them testable without globals while still working when constructed bare.

- [ ] **Step 1: Write the failing test**

Create `test/data/repositories/shop_time_keys_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/data/repositories/daily_closing_repository_impl.dart';
import 'package:maki_mobile_pos/data/repositories/sale_repository_impl.dart';

void main() {
  const ph = 480;
  const est = -300;

  group('SaleRepositoryImpl.dateKeyFor', () {
    test('formats YYYYMMDD in shop time', () {
      expect(SaleRepositoryImpl.dateKeyFor(DateTime.utc(2026, 8, 26, 5, 0), ph), '20260826');
    });

    test('zero-pads month and day', () {
      expect(SaleRepositoryImpl.dateKeyFor(DateTime.utc(2026, 1, 2, 5, 0), ph), '20260102');
    });

    test('an instant after shop midnight uses the new shop day', () {
      // 16:30 UTC Aug 25 == 00:30 Aug 26 PH.
      expect(SaleRepositoryImpl.dateKeyFor(DateTime.utc(2026, 8, 25, 16, 30), ph), '20260826');
    });

    test('agrees with businessDayInt for the same instant', () {
      final instant = DateTime.utc(2026, 8, 25, 16, 30);
      expect(
        SaleRepositoryImpl.dateKeyFor(instant, ph),
        shopDayInt(instant, ph).toString(),
      );
    });

    test('follows a non-PH shop offset', () {
      expect(SaleRepositoryImpl.dateKeyFor(DateTime.utc(2026, 8, 26, 1, 0), est), '20260825');
    });
  });

  group('DailyClosingRepositoryImpl.docIdFor', () {
    test('formats yyyy-MM-dd from a shop wall date', () {
      expect(DailyClosingRepositoryImpl.docIdFor(shopWall(2026, 8, 26)), '2026-08-26');
    });

    test('zero-pads', () {
      expect(DailyClosingRepositoryImpl.docIdFor(shopWall(2026, 1, 2)), '2026-01-02');
    });
  });

  group('shop-day query bounds', () {
    test('span exactly the 24h of a shop day, as instants', () {
      final start = instantOf(shopWall(2026, 8, 26), ph);
      final end = instantOf(shopWall(2026, 8, 26, 23, 59, 59, 999), ph);
      expect(start, DateTime.utc(2026, 8, 25, 16, 0));
      expect(end.difference(start), const Duration(hours: 24) - const Duration(milliseconds: 1));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/repositories/shop_time_keys_test.dart`
Expected: FAIL — `dateKeyFor` is not defined (the current helper is the private instance method `_getDateKey`), and `docIdFor` semantics differ.

- [ ] **Step 3: Write the implementation**

In `lib/data/repositories/sale_repository_impl.dart`:

Add the import and the offset hook to the class (alongside the existing `_firestore` field):

```dart
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
```

```dart
  /// Shop offset supplier. Defaults to the ambient config so the repository
  /// still works when constructed outside Riverpod; the provider passes
  /// `() => ref.read(shopOffsetProvider)`.
  final int Function() _offsetMinutes;
```

with the constructor gaining `int Function()? offsetMinutes` and initialising
`_offsetMinutes = offsetMinutes ?? (() => ShopTimeConfig.offsetMinutes)`.

Replace the private `_getDateKey` (currently at the bottom of the class) with a static, testable version:

```dart
  /// `YYYYMMDD` key for the daily sale counter, in shop time. Must agree
  /// with businessDayInt for the same instant — both feed the same sale
  /// transaction, and the rules check the day server-side.
  static String dateKeyFor(DateTime instant, int offsetMinutes) =>
      shopDayInt(instant, offsetMinutes).toString();
```

and update its call site inside the transaction to `dateKeyFor(sale.createdAt, _offsetMinutes())`.

Replace the `drawer_state` stamp block (and its now-stale comment) with:

```dart
        // Stamp the business-day rollover marker. Reuses sale.createdAt —
        // the same instant already used for the counter's dateKey — and
        // converts it with the SHOP offset, so this matches the rules'
        // phDay() no matter what timezone the device is set to.
        transaction.set(
          _drawerStateRef,
          {'lastSaleDay': businessDayInt(sale.createdAt, _offsetMinutes())},
          SetOptions(merge: true),
        );
```

Replace the bounds in `hasCompletedSaleOn` (keep the `orderBy` and its comment untouched — the index note is still load-bearing):

```dart
  /// [shopWallDate] is a shop wall-clock date (what businessDayProvider
  /// holds), not a device-local one.
  @override
  Future<bool> hasCompletedSaleOn(DateTime shopWallDate) async {
    try {
      final offset = _offsetMinutes();
      final start = instantOf(
        shopWall(shopWallDate.year, shopWallDate.month, shopWallDate.day),
        offset,
      );
      final end = instantOf(
        shopWall(shopWallDate.year, shopWallDate.month, shopWallDate.day,
            23, 59, 59, 999),
        offset,
      );
```

(the rest of the method — the query and the `catch` — is unchanged).

In `lib/data/repositories/daily_closing_repository_impl.dart`, `docIdFor` keeps its body but its contract becomes explicit:

```dart
  /// Document id for a business day. [shopWallDate] must be a shop
  /// wall-clock date (businessDayProvider's value / businessDateOf output),
  /// never a raw instant — a raw instant would key the doc by the device's
  /// day.
  static String docIdFor(DateTime shopWallDate) {
    final y = shopWallDate.year.toString().padLeft(4, '0');
    final m = shopWallDate.month.toString().padLeft(2, '0');
    final d = shopWallDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
```

Finally, fix every remaining compile error from the Task 4 analyze list. The rule for each: if the value in hand is a **shop wall** date (from `businessDayProvider`, `businessDateOf`, or `dateFromBusinessDayInt`) use `businessDayIntOfWall(x)`; if it is a raw **instant** (`DateTime.now()`, `createdAt`, a `Timestamp.toDate()`) use `businessDayInt(x, offset)`.

Wire the offset into the repository providers — in `lib/presentation/providers/sale_provider.dart`, where `SaleRepositoryImpl` is constructed:

```dart
  return SaleRepositoryImpl(
    offsetMinutes: () => ref.read(shopOffsetProvider),
  );
```

(preserving any existing constructor arguments), with the import:

```dart
import 'package:maki_mobile_pos/presentation/providers/shop_time_provider.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/repositories/shop_time_keys_test.dart`
Expected: PASS.

Run: `flutter analyze`
Expected: "No issues found!" — every `businessDayInt` / `businessDateOf` call site now compiles.

Run: `flutter test`
Expected: PASS. If a pre-existing test asserts a date built with `DateTime(...)` (device-local) against a value that is now shop-wall, update the expectation to `shopWall(...)`; on a PH-local dev machine the calendar values are identical, so only the constructor changes.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/sale_repository_impl.dart lib/data/repositories/daily_closing_repository_impl.dart lib/presentation/providers/sale_provider.dart test/data/repositories/shop_time_keys_test.dart
git commit -m "feat(timezone): sale counter key, drawer stamp, closing doc ids in shop time"
```

---

## Task 6: Mobile report ranges + date extensions in shop time

**Files:**
- Modify: `lib/core/utils/report_date_range.dart`
- Modify: `lib/core/extensions/datetime_extensions.dart`
- Modify: the `dateRangeForPreset` call sites (they must pass shop wall "now")
- Test: `test/core/utils/report_date_range_test.dart` (extend)

**Interfaces:**
- Consumes: `shopWall`, `instantOf`, `ShopTimeConfig`, `ShopTimeX` (Task 1); `shopNowProvider` (Task 3).
- Produces:
  - `DateTimeRange dateRangeForPreset(DateRangePreset preset, DateTime shopNow, int offsetMinutes)` — returns **instants**, ready for Firestore bounds.
  - `datetime_extensions`: `startOfDay`/`endOfDay`/`startOfWeek`/… and `isToday`/`isYesterday` now shop-aware via the ambient offset.

**Design note:** `dateRangeForPreset` computes boundaries on the wall value and converts each to an instant on the way out. Every branch's arithmetic stays exactly as-is; only the constructor (`DateTime(...)` → `shopWall(...)`) and the return conversion change. On a PH device the returned instants are identical to today's values.

- [ ] **Step 1: Write the failing test**

Append to `test/core/utils/report_date_range_test.dart`:

```dart
  group('shop-time boundaries', () {
    const ph = 480;

    test('today spans the shop day as instants', () {
      final shopNow = shopWall(2026, 8, 26, 14, 0);
      final r = dateRangeForPreset(DateRangePreset.today, shopNow, ph);
      expect(r.start, DateTime.utc(2026, 8, 25, 16, 0)); // shop midnight
      expect(r.end, DateTime.utc(2026, 8, 26, 15, 59, 59, 999));
    });

    test('yesterday spans the previous shop day', () {
      final shopNow = shopWall(2026, 8, 26, 14, 0);
      final r = dateRangeForPreset(DateRangePreset.yesterday, shopNow, ph);
      expect(r.start, DateTime.utc(2026, 8, 24, 16, 0));
      expect(r.end, DateTime.utc(2026, 8, 25, 15, 59, 59, 999));
    });

    test('thisMonth starts at shop midnight on the 1st', () {
      final shopNow = shopWall(2026, 8, 26, 14, 0);
      final r = dateRangeForPreset(DateRangePreset.thisMonth, shopNow, ph);
      expect(r.start, DateTime.utc(2026, 7, 31, 16, 0)); // Aug 1 00:00 PH
    });

    test('the returned bounds are instants, not wall values', () {
      final r = dateRangeForPreset(DateRangePreset.today, shopWall(2026, 8, 26), ph);
      // Shop midnight is 16:00 UTC the day before — a wall value would read 00:00.
      expect(r.start.hour, 16);
    });

    test('a different shop offset moves the boundary', () {
      final r = dateRangeForPreset(DateRangePreset.today, shopWall(2026, 8, 26, 14, 0), -300);
      expect(r.start, DateTime.utc(2026, 8, 26, 5, 0)); // 00:00 at UTC-5
    });

    test('an instant one millisecond before the end is inside the range', () {
      final r = dateRangeForPreset(DateRangePreset.today, shopWall(2026, 8, 26), ph);
      final lastMoment = r.end;
      expect(lastMoment.isBefore(DateTime.utc(2026, 8, 26, 16, 0)), isTrue);
    });
  });
```

with these imports added to the file:

```dart
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
```

Also create `test/core/extensions/datetime_extensions_shop_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/extensions/datetime_extensions.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';

void main() {
  setUp(() => ShopTimeConfig.apply(
        timezoneId: kDefaultShopTimezoneId,
        offsetMinutes: kDefaultShopOffsetMinutes,
      ));

  test('isToday compares shop days, not device days', () {
    // 00:30 Aug 26 PH — a UTC-5 device would call this Aug 25.
    final instant = DateTime.utc(2026, 8, 25, 16, 30);
    final sameShopDay = DateTime.utc(2026, 8, 26, 5, 0); // 13:00 Aug 26 PH
    expect(instant.isSameShopDay(sameShopDay), isTrue);
  });

  test('startOfDay returns the instant of shop midnight', () {
    final instant = DateTime.utc(2026, 8, 26, 5, 0);
    expect(instant.startOfDay, DateTime.utc(2026, 8, 25, 16, 0));
  });

  test('endOfDay returns the instant of the last millisecond of the shop day', () {
    final instant = DateTime.utc(2026, 8, 26, 5, 0);
    expect(instant.endOfDay, DateTime.utc(2026, 8, 26, 15, 59, 59, 999));
  });

  test('a changed shop offset moves the day boundary', () {
    ShopTimeConfig.apply(timezoneId: 'Asia/Tokyo', offsetMinutes: 540);
    final instant = DateTime.utc(2026, 8, 26, 5, 0);
    expect(instant.startOfDay, DateTime.utc(2026, 8, 25, 15, 0)); // 00:00 JST
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/utils/report_date_range_test.dart test/core/extensions/datetime_extensions_shop_test.dart`
Expected: FAIL — `dateRangeForPreset` takes 2 args, `isSameShopDay` undefined.

- [ ] **Step 3: Write the implementation**

Replace `lib/core/utils/report_date_range.dart`:

```dart
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/date_range_picker.dart';

/// Maps a [DateRangePreset] to a concrete [DateTimeRange] anchored at
/// [shopNow] — a shop **wall-clock** "now" (see shop_time.dart).
///
/// Boundaries are computed on wall values, then converted back to real
/// instants so they can be used directly as Firestore query bounds. Start is
/// shop midnight; end is the true end of the shop day (23:59:59.999) so an
/// inclusive `<=` query never drops a record created in the final second.
/// Callers never pass [DateRangePreset.custom] (the picker routes custom
/// selections to its own date-range picker via onCustomRangeSelected); it
/// falls back to today.
DateTimeRange dateRangeForPreset(
  DateRangePreset preset,
  DateTime shopNow,
  int offsetMinutes,
) {
  final now = shopNow;
  DateTime start;
  DateTime end = shopWall(now.year, now.month, now.day, 23, 59, 59, 999);
  switch (preset) {
    case DateRangePreset.today:
      start = shopWall(now.year, now.month, now.day);
      break;
    case DateRangePreset.yesterday:
      final y = now.subtract(const Duration(days: 1));
      start = shopWall(y.year, y.month, y.day);
      end = shopWall(y.year, y.month, y.day, 23, 59, 59, 999);
      break;
    case DateRangePreset.thisWeek:
      final ws = now.subtract(Duration(days: now.weekday - 1));
      start = shopWall(ws.year, ws.month, ws.day);
      break;
    case DateRangePreset.lastWeek:
      final lws = now.subtract(Duration(days: now.weekday + 6));
      final lwe = now.subtract(Duration(days: now.weekday));
      start = shopWall(lws.year, lws.month, lws.day);
      end = shopWall(lwe.year, lwe.month, lwe.day, 23, 59, 59, 999);
      break;
    case DateRangePreset.thisMonth:
      start = shopWall(now.year, now.month, 1);
      break;
    case DateRangePreset.lastMonth:
      start = shopWall(now.year, now.month - 1, 1);
      end = shopWall(now.year, now.month, 0, 23, 59, 59, 999);
      break;
    case DateRangePreset.thisQuarter:
      final firstMonth = ((now.month - 1) ~/ 3) * 3 + 1;
      start = shopWall(now.year, firstMonth, 1);
      break;
    case DateRangePreset.thisYear:
      start = shopWall(now.year, 1, 1);
      break;
    case DateRangePreset.custom:
      start = shopWall(now.year, now.month, now.day);
      break;
  }
  return DateTimeRange(
    start: instantOf(start, offsetMinutes),
    end: instantOf(end, offsetMinutes),
  );
}
```

In `lib/core/extensions/datetime_extensions.dart`, add the import and make the day-math getters shop-aware. Each computes on the wall view and returns an **instant**, so the results stay usable as query bounds:

```dart
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
```

```dart
  // ==================== DATE CALCULATIONS ====================
  //
  // All of these treat `this` as an instant, do their arithmetic in shop
  // time (ShopTimeConfig — the shop's configured zone, not the device's),
  // and return an instant. That keeps them correct as Firestore query
  // bounds regardless of where the device is.

  DateTime _shopBound(DateTime Function(DateTime wall) f) =>
      instantOf(f(inShopTime), ShopTimeConfig.offsetMinutes);

  /// Start of the shop day (00:00:00.000 shop time), as an instant.
  DateTime get startOfDay => _shopBound((w) => shopWall(w.year, w.month, w.day));

  /// End of the shop day (23:59:59.999 shop time), as an instant.
  DateTime get endOfDay =>
      _shopBound((w) => shopWall(w.year, w.month, w.day, 23, 59, 59, 999));

  /// Start of the shop week (Monday).
  DateTime get startOfWeek => _shopBound(
      (w) => shopWall(w.year, w.month, w.day - (w.weekday - 1)));

  /// End of the shop week (Sunday).
  DateTime get endOfWeek => _shopBound((w) =>
      shopWall(w.year, w.month, w.day + (7 - w.weekday), 23, 59, 59, 999));

  /// Start of the shop month.
  DateTime get startOfMonth => _shopBound((w) => shopWall(w.year, w.month, 1));

  /// End of the shop month.
  DateTime get endOfMonth =>
      _shopBound((w) => shopWall(w.year, w.month + 1, 0, 23, 59, 59, 999));

  /// Start of the calendar quarter — Jan/Apr/Jul/Oct 1st at 00:00 shop time.
  DateTime get startOfQuarter =>
      _shopBound((w) => shopWall(w.year, ((w.month - 1) ~/ 3) * 3 + 1, 1));

  /// End of the calendar quarter — Mar/Jun/Sep/Dec 31st at 23:59:59.999.
  DateTime get endOfQuarter => _shopBound((w) =>
      shopWall(w.year, ((w.month - 1) ~/ 3) * 3 + 4, 0, 23, 59, 59, 999));

  /// Start of the shop year.
  DateTime get startOfYear => _shopBound((w) => shopWall(w.year, 1, 1));

  /// End of the shop year.
  DateTime get endOfYear =>
      _shopBound((w) => shopWall(w.year, 12, 31, 23, 59, 59, 999));

  /// True when both instants fall on the same SHOP day.
  bool isSameShopDay(DateTime other) {
    final a = inShopTime;
    final b = other.inShopTime;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
```

Update `isSameDay`, `isToday`, `isYesterday`, and `toRelativeTime` (around lines 104 and 190–200) to compare in shop time: delegate `isSameDay` to `isSameShopDay`, and replace each `DateTime.now()` reference inside them with `DateTime.now()` compared via `isSameShopDay` / shop-wall day arithmetic. Concretely:

```dart
  bool get isToday => isSameShopDay(DateTime.now());

  bool get isYesterday =>
      isSameShopDay(DateTime.now().subtract(const Duration(days: 1)));
```

Finally update every `dateRangeForPreset` call site to pass shop time. In each report screen (`sales_report_screen.dart`, `labor_report_screen.dart`, `profit_report_screen.dart`, `job_order_reports_screen.dart`, `price_change_report_screen.dart`, `activity_logs_screen.dart`, `void_requests_screen.dart`, `void_request_provider.dart`) replace

```dart
dateRangeForPreset(preset, DateTime.now())
```

with

```dart
dateRangeForPreset(preset, ref.read(shopNowProvider)(), ref.read(shopOffsetProvider))
```

adding `import 'package:maki_mobile_pos/presentation/providers/shop_time_provider.dart';` to each. In a plain (non-`ref`) context use `DateTime.now().inShopTime` and `ShopTimeConfig.offsetMinutes`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/utils/report_date_range_test.dart test/core/extensions/datetime_extensions_shop_test.dart`
Expected: PASS. Existing assertions in `report_date_range_test.dart` that compared device-local `DateTime` values need their expectations converted with `instantOf(shopWall(...), 480)`; the calendar dates themselves do not change.

Run: `flutter analyze && flutter test`
Expected: "No issues found!" and a fully green suite.

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/report_date_range.dart lib/core/extensions/datetime_extensions.dart lib/presentation test/core
git commit -m "feat(timezone): report presets and date extensions computed in shop time"
```

---

## Task 7: Mobile timezone settings screen

**Files:**
- Create: `lib/presentation/mobile/screens/settings/shop_timezone_settings_screen.dart`
- Modify: `lib/config/router/route_names.dart` (name + path), the router file that registers settings routes, `lib/config/router/route_guards.dart`, `lib/presentation/mobile/screens/settings/settings_screen.dart`
- Test: `test/presentation/screens/shop_timezone_settings_screen_test.dart`

**Interfaces:**
- Consumes: `kShopTimezones`, `shopTimezoneById`, `formatOffset` (Task 1); `ShopTimezoneEntity` (Task 2); `shopTimezoneProvider`, `shopTimezoneRepositoryProvider`, `shopNowProvider` (Task 3).
- Produces: route name `shopTimezoneSettings`, path `/settings/timezone`, gated by `Permission.viewSettings` for read and admin for write.

- [ ] **Step 1: Write the failing test**

Create `test/presentation/screens/shop_timezone_settings_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/shop_timezone_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/shop_timezone_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/shop_timezone_settings_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/shop_time_provider.dart';

class _FakeRepo implements ShopTimezoneRepository {
  ShopTimezoneEntity current;
  ShopTimezoneEntity? saved;
  _FakeRepo(this.current);

  @override
  Stream<ShopTimezoneEntity> watch() => Stream.value(current);

  @override
  Future<ShopTimezoneEntity> get() async => current;

  @override
  Future<void> save(ShopTimezoneEntity settings, {required String updatedBy}) async {
    saved = settings;
  }
}

void main() {
  Future<void> pump(WidgetTester tester, _FakeRepo repo) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [shopTimezoneRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ShopTimezoneSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the current shop timezone', (tester) async {
    await pump(tester, _FakeRepo(ShopTimezoneEntity.defaults));
    expect(find.text('Philippines (Manila)'), findsOneWidget);
  });

  testWidgets('lists the curated timezones', (tester) async {
    await pump(tester, _FakeRepo(ShopTimezoneEntity.defaults));
    expect(find.text('Japan (Tokyo)'), findsOneWidget);
  });

  testWidgets('selecting a zone and saving writes both fields', (tester) async {
    final repo = _FakeRepo(ShopTimezoneEntity.defaults);
    await pump(tester, repo);

    await tester.tap(find.text('Japan (Tokyo)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.saved?.timezoneId, 'Asia/Tokyo');
    expect(repo.saved?.offsetMinutes, 540);
  });

  testWidgets('warns that all devices must be updated', (tester) async {
    await pump(tester, _FakeRepo(ShopTimezoneEntity.defaults));
    expect(find.textContaining('every device'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/screens/shop_timezone_settings_screen_test.dart`
Expected: FAIL — `shop_timezone_settings_screen.dart` doesn't exist.

- [ ] **Step 3a: Read the sibling screen first**

Read `lib/presentation/mobile/screens/settings/hr/hr_settings_screen.dart` and `lib/presentation/mobile/screens/settings/cost_code_settings_screen.dart` in full before writing anything. They establish the exact widgets, token helpers, save-button pattern, and snackbar handling this screen must reuse. Do not invent a new card, spacing token, or feedback mechanism — copy theirs. Note the names of the helper widgets they use; the description below refers to behaviour, not to specific widget classes.

- [ ] **Step 3b: Write the implementation**

Create `lib/presentation/mobile/screens/settings/shop_timezone_settings_screen.dart`. Follow the existing settings-screen conventions in this repo: `ConsumerStatefulWidget`, `AppCard` for grouping, the `*Style` token helpers for text, Lucide icons, and neutral colors (color only for status semantics). Structure:

- An `AppBar` titled "Time & Timezone".
- A summary card showing the current shop time, formatted with `DateFormat('EEEE, MMM d · h:mm a').format(ref.watch(shopNowProvider)())`, plus the active zone label and `formatOffset(offset)`.
- A radio-style list built from `kShopTimezones`: each row shows `tz.label` as the title and `formatOffset(tz.offsetMinutes)` as the trailing mono text; tapping selects it into local state.
- A note (not an error color — a neutral informational block): "Changing this affects every device. Phones running an older app version will stop recording sales correctly until they update."
- A "Save" button, enabled only when the selection differs from the stored value and the signed-in user is an admin. On tap: call `ref.read(shopTimezoneRepositoryProvider).save(ShopTimezoneEntity(timezoneId: selected.id, offsetMinutes: selected.offsetMinutes), updatedBy: currentUser.id)`, then show a success `SnackBar`. Wrap in try/catch and surface the failure message in an error `SnackBar`.
- Non-admins see the list read-only (no Save button), matching how other admin-only settings screens behave.

Wire the route:

`lib/config/router/route_names.dart` — add to the name block and the path block:

```dart
  /// Shop timezone editor — `/settings/timezone`.
  static const String shopTimezoneSettings = 'shopTimezoneSettings';
```

```dart
  static const String shopTimezoneSettings = '/settings/timezone';
```

`lib/config/router/route_guards.dart` — add to the permission map next to `'/settings/cost-codes'`:

```dart
    '/settings/timezone': Permission.viewSettings,
```

Register the route in the router file alongside `costCodeSettings`, using the same `GoRoute` shape already used there, pointing at `const ShopTimezoneSettingsScreen()`.

`settings_screen.dart` — add a tile in the administration section, next to "Cost Code Settings":

```dart
                  title: 'Time & Timezone',
                  subtitle: 'Business day and report dates',
                  onTap: () => context.push(RoutePaths.shopTimezoneSettings),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/presentation/screens/shop_timezone_settings_screen_test.dart`
Expected: PASS.

Run: `flutter analyze && flutter test`
Expected: "No issues found!" and a green suite.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/settings/shop_timezone_settings_screen.dart lib/config/router lib/presentation/mobile/screens/settings/settings_screen.dart test/presentation/screens/shop_timezone_settings_screen_test.dart
git commit -m "feat(timezone): mobile Time & Timezone settings screen"
```

---

## Task 8: Web shop-time core (pure)

**Files:**
- Create: `web_admin/src/domain/time/shopTime.ts`
- Create: `web_admin/src/domain/time/shopTimezones.ts`
- Test: `web_admin/src/domain/time/shopTime.test.ts`

Run all web commands from inside `web_admin/`.

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `DEFAULT_SHOP_OFFSET_MINUTES = 480`, `DEFAULT_SHOP_TIMEZONE_ID = 'Asia/Manila'`
  - `interface ShopTimezone { timezoneId: string; offsetMinutes: number }`
  - `setAmbientShopTimezone(tz: ShopTimezone): void`
  - `getAmbientShopTimezone(): ShopTimezone`
  - `shopOffsetMinutes(): number`
  - `shopTimeOf(instant: Date, offsetMinutes?: number): Date` — wall value, read with `getUTC*`
  - `instantOf(wall: Date, offsetMinutes?: number): Date`
  - `shopWall(y, mo, d, h?, mi?, s?, ms?): Date`
  - `shopDayInt(instant: Date, offsetMinutes?: number): number`
  - `shopStartOfDay(instant: Date, offsetMinutes?: number): Date` — an **instant**
  - `shopEndOfDay(instant: Date, offsetMinutes?: number): Date` — an **instant**
  - `shopDateKey(instant: Date, offsetMinutes?: number): string` — `YYYYMMDD`
  - `shopIsoDate(instant: Date, offsetMinutes?: number): string` — `yyyy-MM-dd`
  - `interface ShopTimezoneOption { id: string; label: string; offsetMinutes: number }`, `SHOP_TIMEZONES`, `shopTimezoneById`, `formatOffset`

**Design note:** the codebase has `date-fns-tz` installed but unused. Do **not** reach for it: only fixed-offset zones are supported, so plain offset arithmetic is exact and matches the existing `phDayInt` style. Display formatting uses the platform's `Intl.DateTimeFormat` with a `timeZone` option, which needs no library either.

- [ ] **Step 1: Write the failing test**

Create `web_admin/src/domain/time/shopTime.test.ts`:

```ts
import { beforeEach, describe, expect, it } from 'vitest';
import {
  DEFAULT_SHOP_OFFSET_MINUTES,
  DEFAULT_SHOP_TIMEZONE_ID,
  getAmbientShopTimezone,
  instantOf,
  setAmbientShopTimezone,
  shopDateKey,
  shopDayInt,
  shopEndOfDay,
  shopIsoDate,
  shopOffsetMinutes,
  shopStartOfDay,
  shopTimeOf,
  shopWall,
} from './shopTime';
import { SHOP_TIMEZONES, shopTimezoneById } from './shopTimezones';

const PH = 480;
const EST = -300;

describe('shopTimeOf', () => {
  it('shifts an instant into shop wall time (read with getUTC*)', () => {
    const wall = shopTimeOf(new Date(Date.UTC(2026, 7, 26, 15, 30)), PH);
    expect(wall.getUTCFullYear()).toBe(2026);
    expect(wall.getUTCMonth()).toBe(7);
    expect(wall.getUTCDate()).toBe(26);
    expect(wall.getUTCHours()).toBe(23);
  });
});

describe('instantOf', () => {
  it('round-trips with shopTimeOf', () => {
    const instant = new Date(Date.UTC(2026, 7, 26, 15, 30, 45, 123));
    expect(instantOf(shopTimeOf(instant, PH), PH).getTime()).toBe(instant.getTime());
    expect(instantOf(shopTimeOf(instant, EST), EST).getTime()).toBe(instant.getTime());
  });

  it('maps shop midnight to the right instant', () => {
    expect(instantOf(shopWall(2026, 8, 26), PH).toISOString()).toBe('2026-08-25T16:00:00.000Z');
  });
});

describe('shopDayInt', () => {
  it('matches the rules yyyymmdd shape', () => {
    expect(shopDayInt(new Date(Date.UTC(2026, 7, 26, 5, 0)), PH)).toBe(20260826);
  });

  it('crosses the day boundary at shop midnight', () => {
    const instant = new Date(Date.UTC(2026, 7, 25, 16, 0));
    expect(shopDayInt(instant, PH)).toBe(20260826);
    expect(shopDayInt(instant, EST)).toBe(20260825);
  });

  it('handles a year boundary', () => {
    expect(shopDayInt(new Date(Date.UTC(2026, 11, 31, 16, 0)), PH)).toBe(20270101);
  });
});

describe('day bounds', () => {
  it('shopStartOfDay returns the instant of shop midnight', () => {
    const i = new Date(Date.UTC(2026, 7, 26, 5, 0));
    expect(shopStartOfDay(i, PH).toISOString()).toBe('2026-08-25T16:00:00.000Z');
  });

  it('shopEndOfDay returns the last millisecond of the shop day', () => {
    const i = new Date(Date.UTC(2026, 7, 26, 5, 0));
    expect(shopEndOfDay(i, PH).toISOString()).toBe('2026-08-26T15:59:59.999Z');
  });

  it('the bounds span exactly one day', () => {
    const i = new Date(Date.UTC(2026, 7, 26, 5, 0));
    expect(shopEndOfDay(i, PH).getTime() - shopStartOfDay(i, PH).getTime()).toBe(86_400_000 - 1);
  });
});

describe('key formatting', () => {
  it('shopDateKey is zero-padded YYYYMMDD', () => {
    expect(shopDateKey(new Date(Date.UTC(2026, 0, 2, 5, 0)), PH)).toBe('20260102');
  });

  it('shopIsoDate is zero-padded yyyy-MM-dd', () => {
    expect(shopIsoDate(new Date(Date.UTC(2026, 0, 2, 5, 0)), PH)).toBe('2026-01-02');
  });
});

describe('ambient timezone', () => {
  beforeEach(() =>
    setAmbientShopTimezone({
      timezoneId: DEFAULT_SHOP_TIMEZONE_ID,
      offsetMinutes: DEFAULT_SHOP_OFFSET_MINUTES,
    }),
  );

  it('defaults to Asia/Manila', () => {
    expect(shopOffsetMinutes()).toBe(480);
    expect(getAmbientShopTimezone().timezoneId).toBe('Asia/Manila');
  });

  it('is used when no offset is passed', () => {
    setAmbientShopTimezone({ timezoneId: 'Asia/Tokyo', offsetMinutes: 540 });
    expect(shopDayInt(new Date(Date.UTC(2026, 7, 25, 15, 30)))).toBe(20260826);
  });
});

describe('SHOP_TIMEZONES', () => {
  it('contains the default at +480', () => {
    expect(shopTimezoneById(DEFAULT_SHOP_TIMEZONE_ID)?.offsetMinutes).toBe(480);
  });

  it('has unique ids and in-range offsets', () => {
    const ids = new Set(SHOP_TIMEZONES.map((t) => t.id));
    expect(ids.size).toBe(SHOP_TIMEZONES.length);
    for (const tz of SHOP_TIMEZONES) {
      expect(tz.offsetMinutes).toBeGreaterThanOrEqual(-720);
      expect(tz.offsetMinutes).toBeLessThanOrEqual(840);
    }
  });

  it('mirrors the Dart catalog', () => {
    // Keep in lock-step with lib/core/utils/shop_timezones.dart.
    expect(SHOP_TIMEZONES.length).toBe(15);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `web_admin/`): `npm run test -- shopTime`
Expected: FAIL — cannot resolve `./shopTime`.

- [ ] **Step 3: Write the implementation**

Create `web_admin/src/domain/time/shopTime.ts`:

```ts
// Shop-timezone helpers — the TypeScript half of lib/core/utils/shop_time.dart.
//
// The shop runs on one configured timezone (settings/general, default
// Asia/Manila UTC+8). Every calendar computation — "what day is it", range
// boundaries, day grouping — uses that zone rather than the browser's, so a
// laptop set to another timezone still agrees with the mobile app and with
// the Firestore rules' phDay().
//
// Two representations, kept strictly apart:
//   * instant — a real point in time. What Firestore stores. Never shifted
//     before writing.
//   * shop wall time — an instant shifted by the shop offset so its UTC
//     getters read shop-local. For day math and display only; convert back
//     with instantOf() before using it as a query bound.
//
// Only fixed-offset (no-DST) zones are supported, so plain offset arithmetic
// is exact. Do NOT use date-fns' startOfDay/endOfDay on wall values — they
// read local getters and would double-shift.

export const DEFAULT_SHOP_OFFSET_MINUTES = 480;
export const DEFAULT_SHOP_TIMEZONE_ID = 'Asia/Manila';

export interface ShopTimezone {
  timezoneId: string;
  offsetMinutes: number;
}

const MINUTE_MS = 60_000;

let ambient: ShopTimezone = {
  timezoneId: DEFAULT_SHOP_TIMEZONE_ID,
  offsetMinutes: DEFAULT_SHOP_OFFSET_MINUTES,
};

/** Set from the settings doc at bootstrap and on every change. */
export function setAmbientShopTimezone(tz: ShopTimezone): void {
  ambient = tz;
}

export function getAmbientShopTimezone(): ShopTimezone {
  return ambient;
}

export function shopOffsetMinutes(): number {
  return ambient.offsetMinutes;
}

/** Shop wall-clock view of `instant`. Read it with getUTC*. Do not persist. */
export function shopTimeOf(instant: Date, offsetMinutes = shopOffsetMinutes()): Date {
  return new Date(instant.getTime() + offsetMinutes * MINUTE_MS);
}

/** The real instant for a shop wall-clock value — inverse of shopTimeOf. */
export function instantOf(wall: Date, offsetMinutes = shopOffsetMinutes()): Date {
  return new Date(wall.getTime() - offsetMinutes * MINUTE_MS);
}

/** Builds a shop wall-clock value from calendar fields (month is 1-based). */
export function shopWall(
  year: number,
  month: number,
  day: number,
  hour = 0,
  minute = 0,
  second = 0,
  ms = 0,
): Date {
  return new Date(Date.UTC(year, month - 1, day, hour, minute, second, ms));
}

/** yyyymmdd int in shop time — must equal the rules' phDay(). */
export function shopDayInt(instant: Date, offsetMinutes = shopOffsetMinutes()): number {
  const w = shopTimeOf(instant, offsetMinutes);
  return w.getUTCFullYear() * 10000 + (w.getUTCMonth() + 1) * 100 + w.getUTCDate();
}

/** Instant of shop midnight for the shop day containing `instant`. */
export function shopStartOfDay(instant: Date, offsetMinutes = shopOffsetMinutes()): Date {
  const w = shopTimeOf(instant, offsetMinutes);
  return instantOf(
    shopWall(w.getUTCFullYear(), w.getUTCMonth() + 1, w.getUTCDate()),
    offsetMinutes,
  );
}

/** Instant of the last millisecond of that shop day. */
export function shopEndOfDay(instant: Date, offsetMinutes = shopOffsetMinutes()): Date {
  const w = shopTimeOf(instant, offsetMinutes);
  return instantOf(
    shopWall(w.getUTCFullYear(), w.getUTCMonth() + 1, w.getUTCDate(), 23, 59, 59, 999),
    offsetMinutes,
  );
}

/** YYYYMMDD in shop time — the sale-counter key. */
export function shopDateKey(instant: Date, offsetMinutes = shopOffsetMinutes()): string {
  return `${shopDayInt(instant, offsetMinutes)}`;
}

/** yyyy-MM-dd in shop time — closing doc ids, pay-period dates. */
export function shopIsoDate(instant: Date, offsetMinutes = shopOffsetMinutes()): string {
  const w = shopTimeOf(instant, offsetMinutes);
  const y = w.getUTCFullYear();
  const m = `${w.getUTCMonth() + 1}`.padStart(2, '0');
  const d = `${w.getUTCDate()}`.padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/** Formats an instant for display in the shop's zone. */
export function formatInShopZone(
  instant: Date,
  options: Intl.DateTimeFormatOptions,
  timezoneId = ambient.timezoneId,
): string {
  return new Intl.DateTimeFormat('en-PH', { ...options, timeZone: timezoneId }).format(instant);
}
```

Create `web_admin/src/domain/time/shopTimezones.ts` as the exact mirror of the Dart catalog (same 15 ids, same labels, same offsets, same order), exporting `ShopTimezoneOption`, `SHOP_TIMEZONES`, `shopTimezoneById(id)`, `formatOffset(offsetMinutes)` (`'+08:00'` shape), and `DEFAULT_SHOP_TIMEZONE` — with a header comment pointing at `lib/core/utils/shop_timezones.dart` as the lock-step counterpart.

- [ ] **Step 4: Run tests to verify they pass**

Run (from `web_admin/`): `npm run test -- shopTime`
Expected: PASS.

Run: `npm run typecheck`
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/time/
git commit -m "feat(timezone): web shop-time core and timezone catalog"
```

---

## Task 9: Web settings repository, DI, and `phDayInt`

**Files:**
- Create: `web_admin/src/domain/repositories/ShopTimezoneRepository.ts`
- Create: `web_admin/src/data/repositories/FirestoreShopTimezoneRepository.ts`
- Modify: `web_admin/src/core/utils/businessDay.ts`
- Modify: `web_admin/src/infrastructure/di/container.tsx`
- Test: `web_admin/src/data/repositories/FirestoreShopTimezoneRepository.test.ts`, `web_admin/src/core/utils/businessDay.test.ts` (extend)

**Interfaces:**
- Consumes: `ShopTimezone`, `DEFAULT_SHOP_*`, `setAmbientShopTimezone`, `shopDayInt` (Task 8); `FirestoreCollections.settings`, `SettingsDocs.general` (existing).
- Produces:
  - `interface ShopTimezoneRepository { watch(cb: (tz: ShopTimezone) => void): () => void; get(): Promise<ShopTimezone>; save(tz: ShopTimezone, updatedBy: string): Promise<void>; }`
  - `class FirestoreShopTimezoneRepository implements ShopTimezoneRepository`
  - `parseShopTimezone(data: Record<string, unknown> | undefined): ShopTimezone` — exported for tests
  - `useShopTimezoneRepo(): ShopTimezoneRepository`
  - `phDayInt(now?: Date, offsetMinutes?: number): number` — now offset-aware

- [ ] **Step 1: Write the failing test**

Create `web_admin/src/data/repositories/FirestoreShopTimezoneRepository.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { parseShopTimezone } from './FirestoreShopTimezoneRepository';

describe('parseShopTimezone', () => {
  it('a missing doc reads as the defaults', () => {
    expect(parseShopTimezone(undefined)).toEqual({
      timezoneId: 'Asia/Manila',
      offsetMinutes: 480,
    });
  });

  it('an empty doc reads as the defaults', () => {
    expect(parseShopTimezone({})).toEqual({ timezoneId: 'Asia/Manila', offsetMinutes: 480 });
  });

  it('reads a stored timezone', () => {
    expect(parseShopTimezone({ timezoneId: 'Asia/Tokyo', tzOffsetMinutes: 540 })).toEqual({
      timezoneId: 'Asia/Tokyo',
      offsetMinutes: 540,
    });
  });

  it('ignores unrelated keys in the shared general doc', () => {
    expect(
      parseShopTimezone({ timezoneId: 'UTC', tzOffsetMinutes: 0, other: true }).offsetMinutes,
    ).toBe(0);
  });

  it('falls back on an out-of-range offset', () => {
    expect(parseShopTimezone({ tzOffsetMinutes: 99999 }).offsetMinutes).toBe(480);
  });

  it('falls back on a non-numeric offset', () => {
    expect(parseShopTimezone({ tzOffsetMinutes: 'eight' }).offsetMinutes).toBe(480);
  });

  it('falls back on a non-integer offset', () => {
    expect(parseShopTimezone({ tzOffsetMinutes: 480.5 }).offsetMinutes).toBe(480);
  });
});
```

Append to `web_admin/src/core/utils/businessDay.test.ts`:

```ts
describe('phDayInt with a configured offset', () => {
  it('defaults to +8 when no offset is passed', () => {
    expect(phDayInt(new Date(Date.UTC(2026, 7, 25, 16, 0)))).toBe(20260826);
  });

  it('follows an explicit offset', () => {
    expect(phDayInt(new Date(Date.UTC(2026, 7, 25, 16, 0)), -300)).toBe(20260825);
  });

  it('agrees with shopDayInt', () => {
    const i = new Date(Date.UTC(2026, 7, 25, 16, 0));
    expect(phDayInt(i, 540)).toBe(shopDayInt(i, 540));
  });
});
```

with `import { shopDayInt } from '@/domain/time/shopTime';` added to that test file.

- [ ] **Step 2: Run tests to verify they fail**

Run (from `web_admin/`): `npm run test -- FirestoreShopTimezoneRepository businessDay`
Expected: FAIL — `parseShopTimezone` not exported / `phDayInt` takes one argument.

- [ ] **Step 3: Write the implementation**

Create `web_admin/src/domain/repositories/ShopTimezoneRepository.ts`:

```ts
import type { ShopTimezone } from '@/domain/time/shopTime';

/** The timezone keys of the shared settings/general doc. */
export interface ShopTimezoneRepository {
  /** Subscribes to changes; returns the unsubscribe function. */
  watch(onChange: (tz: ShopTimezone) => void): () => void;
  get(): Promise<ShopTimezone>;
  save(tz: ShopTimezone, updatedBy: string): Promise<void>;
}
```

Create `web_admin/src/data/repositories/FirestoreShopTimezoneRepository.ts`:

```ts
// Firestore implementation over settings/general — the doc shared with the
// mobile app. Saves MERGE rather than overwrite: general is a bucket for
// other future settings, unlike settings/hr which is a full overwrite.

import {
  doc,
  getDoc,
  onSnapshot,
  serverTimestamp,
  setDoc,
  type Firestore,
} from 'firebase/firestore';
import type { ShopTimezoneRepository } from '@/domain/repositories/ShopTimezoneRepository';
import {
  DEFAULT_SHOP_OFFSET_MINUTES,
  DEFAULT_SHOP_TIMEZONE_ID,
  type ShopTimezone,
} from '@/domain/time/shopTime';
import { FirestoreCollections, SettingsDocs } from '@/infrastructure/firebase/collections';

const MIN_OFFSET = -720;
const MAX_OFFSET = 840;

/**
 * Defensive read: a missing doc, a missing key, a non-integer value, or an
 * out-of-range offset all fall back to the default. A bad value here would
 * break the business day on every browser, so the safest value wins.
 */
export function parseShopTimezone(data: Record<string, unknown> | undefined): ShopTimezone {
  const rawOffset = data?.tzOffsetMinutes;
  const rawId = data?.timezoneId;

  const offsetMinutes =
    typeof rawOffset === 'number' &&
    Number.isInteger(rawOffset) &&
    rawOffset >= MIN_OFFSET &&
    rawOffset <= MAX_OFFSET
      ? rawOffset
      : DEFAULT_SHOP_OFFSET_MINUTES;

  const timezoneId = typeof rawId === 'string' && rawId.length > 0 ? rawId : DEFAULT_SHOP_TIMEZONE_ID;

  return { timezoneId, offsetMinutes };
}

export class FirestoreShopTimezoneRepository implements ShopTimezoneRepository {
  constructor(private readonly db: Firestore) {}

  private docRef() {
    return doc(this.db, FirestoreCollections.settings, SettingsDocs.general);
  }

  watch(onChange: (tz: ShopTimezone) => void): () => void {
    return onSnapshot(this.docRef(), (snap) => {
      onChange(parseShopTimezone(snap.data() as Record<string, unknown> | undefined));
    });
  }

  async get(): Promise<ShopTimezone> {
    const snap = await getDoc(this.docRef());
    return parseShopTimezone(snap.data() as Record<string, unknown> | undefined);
  }

  async save(tz: ShopTimezone, updatedBy: string): Promise<void> {
    await setDoc(
      this.docRef(),
      {
        timezoneId: tz.timezoneId,
        tzOffsetMinutes: tz.offsetMinutes,
        updatedAt: serverTimestamp(),
        updatedBy,
      },
      { merge: true },
    );
  }
}
```

Replace `web_admin/src/core/utils/businessDay.ts`:

```ts
import { shopDayInt, shopOffsetMinutes } from '@/domain/time/shopTime';

/**
 * Shop business day as yyyymmdd — must match mobile's businessDayInt and the
 * rules' phDay(). Defaults to the configured shop offset (Asia/Manila +8
 * until an admin changes it in settings).
 */
export function phDayInt(now: Date = new Date(), offsetMinutes = shopOffsetMinutes()): number {
  return shopDayInt(now, offsetMinutes);
}
```

In `web_admin/src/infrastructure/di/container.tsx`, register the repository the same way `hrSettingsRepo` is (import, add `shopTimezoneRepo: ShopTimezoneRepository` to the container type, instantiate `new FirestoreShopTimezoneRepository(db)`, and export a `useShopTimezoneRepo()` hook next to `useHrSettingsRepo()`).

In the same file, start the ambient subscription when the container mounts, so every consumer — including non-React helpers — sees the shop zone:

```tsx
  // Keep the ambient shop timezone in sync for the whole app. Helpers like
  // counterKey and resolvePreset read it without a React context, so this has
  // to run once at the container level rather than per page.
  useEffect(() => {
    return container.shopTimezoneRepo.watch(setAmbientShopTimezone);
  }, [container]);
```

with the imports `import { useEffect } from 'react';` (if not already present) and `import { setAmbientShopTimezone } from '@/domain/time/shopTime';`.

- [ ] **Step 4: Run tests to verify they pass**

Run (from `web_admin/`): `npm run test -- FirestoreShopTimezoneRepository businessDay`
Expected: PASS.

Run: `npm run typecheck && npm run test`
Expected: no type errors, full suite green.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/repositories/ShopTimezoneRepository.ts web_admin/src/data/repositories/FirestoreShopTimezoneRepository.ts web_admin/src/core/utils/businessDay.ts web_admin/src/infrastructure/di/container.tsx web_admin/src/core/utils/businessDay.test.ts web_admin/src/data/repositories/FirestoreShopTimezoneRepository.test.ts
git commit -m "feat(timezone): web settings repository, DI bootstrap, offset-aware phDayInt"
```

---

## Task 10: Web local-time stragglers

**Files:**
- Modify: `web_admin/src/domain/reports/dateRange.ts`
- Modify: `web_admin/src/domain/sales/saleNumber.ts`
- Modify: `web_admin/src/domain/hr/payPeriod.ts`
- Modify: `web_admin/src/presentation/features/logs/ActivityLogsPage.tsx`
- Modify: `web_admin/src/presentation/components/common/DateRangePicker.tsx`
- Test: `web_admin/src/domain/reports/dateRange.test.ts`, `web_admin/src/domain/sales/saleNumber.test.ts`, `web_admin/src/domain/hr/payPeriod.test.ts` (extend each)

**Interfaces:**
- Consumes: `shopStartOfDay`, `shopEndOfDay`, `shopTimeOf`, `shopWall`, `instantOf`, `shopDateKey`, `shopIsoDate`, `shopDayInt`, `formatInShopZone` (Task 8).
- Produces:
  - `resolvePreset(preset, now?: Date, offsetMinutes?: number): DateRange` — bounds are **instants**
  - `counterKey(date: Date, offsetMinutes?: number): string`
  - `payPeriodFor(anchor: Date, weekStartDay: number, offsetMinutes?: number): PayPeriod`

**Why `counterKey` matters most:** it currently runs on browser-local time inside the same sale transaction whose `drawer_state` write is checked against UTC+8 — the two can disagree by a day today, on any browser outside PH.

- [ ] **Step 1: Write the failing tests**

Append to `web_admin/src/domain/reports/dateRange.test.ts`:

```ts
describe('resolvePreset in shop time', () => {
  const PH = 480;

  it('today spans the shop day as instants', () => {
    const r = resolvePreset('today', new Date(Date.UTC(2026, 7, 26, 5, 0)), PH);
    expect(r.start.toISOString()).toBe('2026-08-25T16:00:00.000Z');
    expect(r.end.toISOString()).toBe('2026-08-26T15:59:59.999Z');
  });

  it('yesterday spans the previous shop day', () => {
    const r = resolvePreset('yesterday', new Date(Date.UTC(2026, 7, 26, 5, 0)), PH);
    expect(r.start.toISOString()).toBe('2026-08-24T16:00:00.000Z');
    expect(r.end.toISOString()).toBe('2026-08-25T15:59:59.999Z');
  });

  it('last7 covers seven shop days inclusive', () => {
    const r = resolvePreset('last7', new Date(Date.UTC(2026, 7, 26, 5, 0)), PH);
    expect(r.start.toISOString()).toBe('2026-08-19T16:00:00.000Z');
    expect(r.end.getTime() - r.start.getTime()).toBe(7 * 86_400_000 - 1);
  });

  it('last30 covers thirty shop days inclusive', () => {
    const r = resolvePreset('last30', new Date(Date.UTC(2026, 7, 26, 5, 0)), PH);
    expect(r.end.getTime() - r.start.getTime()).toBe(30 * 86_400_000 - 1);
  });

  it('thisMonth starts at shop midnight on the 1st', () => {
    const r = resolvePreset('thisMonth', new Date(Date.UTC(2026, 7, 26, 5, 0)), PH);
    expect(r.start.toISOString()).toBe('2026-07-31T16:00:00.000Z');
  });

  it('an instant just after shop midnight belongs to the new day', () => {
    const r = resolvePreset('today', new Date(Date.UTC(2026, 7, 25, 16, 1)), PH);
    expect(r.start.toISOString()).toBe('2026-08-25T16:00:00.000Z');
  });
});
```

Append to `web_admin/src/domain/sales/saleNumber.test.ts`:

```ts
describe('counterKey in shop time', () => {
  const PH = 480;

  it('uses the shop day, not the browser day', () => {
    // 16:30 UTC Aug 25 is 00:30 Aug 26 in PH.
    expect(counterKey(new Date(Date.UTC(2026, 7, 25, 16, 30)), PH)).toBe('20260826');
  });

  it('agrees with phDayInt for the same instant — same sale transaction', () => {
    const i = new Date(Date.UTC(2026, 7, 25, 16, 30));
    expect(counterKey(i, PH)).toBe(`${phDayInt(i, PH)}`);
  });

  it('formatSaleNumber uses the shop day', () => {
    expect(formatSaleNumber(new Date(Date.UTC(2026, 7, 25, 16, 30)), 7, PH)).toBe(
      'SALE-20260826-007',
    );
  });
});
```

with `import { phDayInt } from '@/core/utils/businessDay';` added there.

Append to `web_admin/src/domain/hr/payPeriod.test.ts`:

```ts
describe('payPeriodFor in shop time', () => {
  const PH = 480;

  it('anchors on the shop day', () => {
    // 16:30 UTC Sun Aug 30 is 00:30 Mon Aug 31 in PH — a Monday-start week
    // must therefore begin on Aug 31, not Aug 24.
    const p = payPeriodFor(new Date(Date.UTC(2026, 7, 30, 16, 30)), 1, PH);
    expect(p.start).toBe('2026-08-31');
    expect(p.end).toBe('2026-09-06');
    expect(p.dates).toHaveLength(7);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run (from `web_admin/`): `npm run test -- dateRange saleNumber payPeriod`
Expected: FAIL — extra arguments not accepted; local-time results differ from the shop-time expectations.

- [ ] **Step 3: Write the implementation**

`dateRange.ts` — drop the date-fns local helpers and compute on shop time. Keep `DateRange`, `RangePreset`, and `PRESET_LABELS` exactly as they are; replace only `resolvePreset`:

```ts
import { instantOf, shopEndOfDay, shopStartOfDay, shopTimeOf, shopWall, shopOffsetMinutes } from '@/domain/time/shopTime';

/**
 * Resolves a FIXED preset (not 'custom') to a concrete range, computed in the
 * shop's timezone and returned as instants ready for Firestore bounds.
 * `now` and `offsetMinutes` are injectable so this stays deterministic in tests.
 */
export function resolvePreset(
  preset: Exclude<RangePreset, 'custom'>,
  now: Date = new Date(),
  offsetMinutes: number = shopOffsetMinutes(),
): DateRange {
  const dayBefore = (d: Date, n: number) => new Date(d.getTime() - n * 86_400_000);
  const end = shopEndOfDay(now, offsetMinutes);

  switch (preset) {
    case 'today':
      return { start: shopStartOfDay(now, offsetMinutes), end };
    case 'yesterday': {
      const y = dayBefore(now, 1);
      return { start: shopStartOfDay(y, offsetMinutes), end: shopEndOfDay(y, offsetMinutes) };
    }
    case 'last7':
      return { start: shopStartOfDay(dayBefore(now, 6), offsetMinutes), end };
    case 'last30':
      return { start: shopStartOfDay(dayBefore(now, 29), offsetMinutes), end };
    case 'thisMonth': {
      const w = shopTimeOf(now, offsetMinutes);
      return {
        start: instantOf(shopWall(w.getUTCFullYear(), w.getUTCMonth() + 1, 1), offsetMinutes),
        end,
      };
    }
  }
}
```

`saleNumber.ts`:

```ts
import { shopDateKey, shopOffsetMinutes } from '@/domain/time/shopTime';

/**
 * YYYYMMDD key for the daily sale counter (settings/sale_counters), in SHOP
 * time. This runs inside the same transaction whose drawer_state write the
 * rules check against phDay() — a browser-local key could disagree by a day.
 */
export function counterKey(date: Date, offsetMinutes: number = shopOffsetMinutes()): string {
  return shopDateKey(date, offsetMinutes);
}

/** Human sale number: SALE-YYYYMMDD-NNN (sequence zero-padded to >= 3). */
export function formatSaleNumber(
  date: Date,
  seq: number,
  offsetMinutes: number = shopOffsetMinutes(),
): string {
  return `SALE-${counterKey(date, offsetMinutes)}-${`${seq}`.padStart(3, '0')}`;
}
```

`payPeriod.ts` — anchor on the shop day and build the dates from shop wall values:

```ts
import { shopOffsetMinutes, shopTimeOf, shopWall } from '@/domain/time/shopTime';

export interface PayPeriod { start: string; end: string; dates: string[] }

const isoOfWall = (w: Date) =>
  `${w.getUTCFullYear()}-${String(w.getUTCMonth() + 1).padStart(2, '0')}-${String(w.getUTCDate()).padStart(2, '0')}`;

/** 7-day period containing `anchor`, starting on ISO weekday `weekStartDay` (1=Mon..7=Sun), in shop time. */
export function payPeriodFor(
  anchor: Date,
  weekStartDay: number,
  offsetMinutes: number = shopOffsetMinutes(),
): PayPeriod {
  const w = shopTimeOf(anchor, offsetMinutes);
  const a = shopWall(w.getUTCFullYear(), w.getUTCMonth() + 1, w.getUTCDate());
  const isoDow = ((a.getUTCDay() + 6) % 7) + 1; // JS Sun=0 → ISO 1..7
  const diff = (isoDow - weekStartDay + 7) % 7;
  const start = new Date(a.getTime() - diff * 86_400_000);
  const dates = Array.from({ length: 7 }, (_, k) =>
    isoOfWall(new Date(start.getTime() + k * 86_400_000)),
  );
  return { start: dates[0], end: dates[6], dates };
}

export function shiftPeriod(p: PayPeriod, weeks: number): PayPeriod {
  const [y, m, d] = p.start.split('-').map(Number);
  const s = shopWall(y, m, d + weeks * 7);
  const dates = Array.from({ length: 7 }, (_, k) =>
    isoOfWall(new Date(s.getTime() + k * 86_400_000)),
  );
  return { start: dates[0], end: dates[6], dates };
}
```

`ActivityLogsPage.tsx` — replace the four local-time helpers so grouping headers follow the shop day:

```tsx
function dayKey(d: Date): string {
  return shopIsoDate(d);
}

function isSameShopDay(a: Date, b: Date): boolean {
  return shopDayInt(a) === shopDayInt(b);
}

function dateLabel(d: Date): string {
  const now = new Date();
  if (isSameShopDay(d, now)) return 'Today';
  if (isSameShopDay(d, new Date(now.getTime() - 86_400_000))) return 'Yesterday';
  return dateGroupFmt.format(d);
}
```

and give the two `Intl.DateTimeFormat` instances the shop zone so the rendered day and time match the grouping:

```tsx
const dateGroupFmt = new Intl.DateTimeFormat('en-PH', {
  weekday: 'long',
  month: 'long',
  day: 'numeric',
  year: 'numeric',
  timeZone: getAmbientShopTimezone().timezoneId,
});

const timeFmt = new Intl.DateTimeFormat('en-PH', {
  hour: 'numeric',
  minute: '2-digit',
  hour12: true,
  timeZone: getAmbientShopTimezone().timezoneId,
});
```

with `import { getAmbientShopTimezone, shopDayInt, shopIsoDate } from '@/domain/time/shopTime';`. Delete the now-unused `isToday`/`isYesterday` helpers.

`DateRangePicker.tsx` — `new Date("2026-08-26")` parses as UTC midnight and `startOfDay` then shifts it to browser-local, an off-by-one on any negative-offset browser. Parse the `yyyy-MM-dd` input as a shop wall date instead:

```tsx
const [sy, sm, sd] = startStr.split('-').map(Number);
const [ey, em, ed] = endStr.split('-').map(Number);
// ...
        start: instantOf(shopWall(sy, sm, sd)),
        end: instantOf(shopWall(ey, em, ed, 23, 59, 59, 999)),
```

and change the two `max={format(new Date(), 'yyyy-MM-dd')}` props to `max={shopIsoDate(new Date())}` so "today" in the picker is the shop's today. Drop the `startOfDay`/`endOfDay`/`format` imports if they become unused, and add `import { instantOf, shopIsoDate, shopWall } from '@/domain/time/shopTime';`.

- [ ] **Step 4: Run tests to verify they pass**

Run (from `web_admin/`): `npm run test -- dateRange saleNumber payPeriod`
Expected: PASS.

Run: `npm run typecheck && npm run test && npm run build`
Expected: no type errors, full suite green, clean build. Existing assertions that used browser-local expectations need converting to the shop-time equivalents; on a PH-local dev machine the calendar dates are unchanged.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/reports/dateRange.ts web_admin/src/domain/sales/saleNumber.ts web_admin/src/domain/hr/payPeriod.ts web_admin/src/presentation/features/logs/ActivityLogsPage.tsx web_admin/src/presentation/components/common/DateRangePicker.tsx web_admin/src/domain web_admin/src/presentation
git commit -m "fix(timezone): web date ranges, counter key, pay periods and log grouping use shop time"
```

---

## Task 11: Web Time & Timezone settings page

**Files:**
- Create: `web_admin/src/presentation/features/settings/TimezoneSettingsPage.tsx`
- Modify: `web_admin/src/presentation/router/routePaths.ts`, `routes.tsx`, `routeGuards.ts`
- Modify: `web_admin/src/presentation/features/settings/SettingsPage.tsx`
- Test: `web_admin/src/presentation/features/settings/TimezoneSettingsPage.test.tsx`, `web_admin/src/presentation/router/routeGuards.test.ts` (extend)

**Interfaces:**
- Consumes: `SHOP_TIMEZONES`, `shopTimezoneById`, `formatOffset` (Task 8); `useShopTimezoneRepo` (Task 9).
- Produces: `RoutePaths.timezoneSettings = '/settings/timezone'` (matching the mobile path exactly, per the mirroring comment at the top of `routePaths.ts`), gated by `Permission.viewSettings`.

**Reminder:** a new gated web route needs all three edits — `routePaths.ts`, `routes.tsx`, and `routeGuards.ts`. Missing the guard silently leaves the route open or shut.

- [ ] **Step 0: Read the sibling page, its test, and the route registration first**

Read `web_admin/src/presentation/features/hr/HrSettingsPage.tsx` and its test, plus the `costCodeSettings` entry in `routes.tsx` and the "General" section of `SettingsPage.tsx`. They define the page shell, the DI mocking approach for tests, the lazy-import/`ProtectedRoute` shape, and the link component's real prop names. Mirror them exactly rather than inventing equivalents — the prop names used in the sketches below are illustrative, the sibling file is authoritative.

- [ ] **Step 1: Write the failing test**

Create `web_admin/src/presentation/features/settings/TimezoneSettingsPage.test.tsx` covering: the current zone renders; the curated list renders; picking a zone and clicking Save calls `save` with `{timezoneId: 'Asia/Tokyo', offsetMinutes: 540}`; Save is disabled until the selection changes; the "affects every device" warning is present. Mock the repository through the DI provider the same way the existing settings-page tests do.

Append to `web_admin/src/presentation/router/routeGuards.test.ts`:

```ts
describe('/settings/timezone', () => {
  it('is reachable by an admin', () => {
    expect(canAccess(RoutePaths.timezoneSettings, adminUser)).toBe(true);
  });

  it('is blocked for a cashier', () => {
    expect(canAccess(RoutePaths.timezoneSettings, cashierUser)).toBe(false);
  });

  it('is blocked for a deactivated admin', () => {
    expect(canAccess(RoutePaths.timezoneSettings, { ...adminUser, isActive: false })).toBe(false);
  });
});
```

(reusing whatever user fixtures that file already defines).

- [ ] **Step 2: Run tests to verify they fail**

Run (from `web_admin/`): `npm run test -- TimezoneSettingsPage routeGuards`
Expected: FAIL — module not found, `RoutePaths.timezoneSettings` undefined.

- [ ] **Step 3: Write the implementation**

`routePaths.ts` — add next to the other settings paths:

```ts
  timezoneSettings: '/settings/timezone',
```

`routeGuards.ts` — add to `protectedRoutes`:

```ts
  [RoutePaths.timezoneSettings, Permission.viewSettings],
```

`routes.tsx` — register the route beside `costCodeSettings`, following that entry's exact shape (lazy import + `ProtectedRoute` wrapper as used there).

`TimezoneSettingsPage.tsx` — follow the layout and components of `HrSettingsPage.tsx`: page header, a card with the current shop time (`formatInShopZone(new Date(), { dateStyle: 'full', timeStyle: 'short' })`), a select/radio list over `SHOP_TIMEZONES` showing `label` and `formatOffset(offsetMinutes)`, the informational warning that changing the zone affects every device and that phones on an older app version will stop recording sales correctly until they update, and a Save button that calls `useShopTimezoneRepo().save(...)` with the current user's uid, disabled while unchanged or saving. Show success and failure via the same toast/snackbar mechanism the other settings pages use.

`SettingsPage.tsx` — add a link inside the existing `<Section title="General">`, above "About":

```tsx
        <SettingsLink
          to={RoutePaths.timezoneSettings}
          title="Time & timezone"
          subtitle="Business day and report dates"
        />
```

matching the props of the neighbouring "About" link.

- [ ] **Step 4: Run tests to verify they pass**

Run (from `web_admin/`): `npm run test -- TimezoneSettingsPage routeGuards`
Expected: PASS.

Run: `npm run typecheck && npm run test && npm run build`
Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/presentation/features/settings web_admin/src/presentation/router
git commit -m "feat(timezone): web Time & timezone settings page"
```

---

## Task 12: Firestore rules follow the configured offset

**Files:**
- Modify: `firestore.rules`
- Test: `tools/firestore-rules-test/test/rules.test.js`

**Interfaces:**
- Consumes: the `settings/general` document shape (`tzOffsetMinutes`).
- Produces: `shopOffsetMinutes()`, an offset-aware `phDay()`, and validation on `settings/general` writes.

**Safety property:** with `settings/general` absent or missing `tzOffsetMinutes`, `shopOffsetMinutes()` returns 480 — byte-identical to today's behaviour. That is what makes the deploy order in Task 13 safe in either direction.

- [ ] **Step 1: Write the failing test**

Append to `tools/firestore-rules-test/test/rules.test.js` (using the file's existing `as(...)`, `seedRaw`-style helpers and the `phDay()` test helper already defined near line 83):

```js
// ---------------------------------------------------------------------------
// settings/general — the shop timezone
describe("/settings/general (shop timezone)", () => {
  it("any active user can read it", async () => {
    await assertSucceeds(as("cashier").collection("settings").doc("general").get());
  });

  it("an admin can write a valid offset", async () => {
    await assertSucceeds(
      as("admin").collection("settings").doc("general")
        .set({ timezoneId: "Asia/Tokyo", tzOffsetMinutes: 540 }, { merge: true })
    );
  });

  it("an admin can write a negative offset", async () => {
    await assertSucceeds(
      as("admin").collection("settings").doc("general")
        .set({ timezoneId: "UTC", tzOffsetMinutes: -300 }, { merge: true })
    );
  });

  it("rejects an out-of-range offset", async () => {
    await assertFails(
      as("admin").collection("settings").doc("general")
        .set({ tzOffsetMinutes: 99999 }, { merge: true })
    );
  });

  it("rejects a non-integer offset", async () => {
    await assertFails(
      as("admin").collection("settings").doc("general")
        .set({ tzOffsetMinutes: "eight" }, { merge: true })
    );
  });

  it("a cashier cannot write it", async () => {
    await assertFails(
      as("cashier").collection("settings").doc("general")
        .set({ tzOffsetMinutes: 0 }, { merge: true })
    );
  });

  it("a deactivated admin cannot write it", async () => {
    await assertFails(
      as("inactiveAdmin").collection("settings").doc("general")
        .set({ tzOffsetMinutes: 0 }, { merge: true })
    );
  });
});

// ---------------------------------------------------------------------------
// drawer_state honours the configured offset
describe("/drawer_state with a configured timezone", () => {
  // yyyymmdd for `d` at an arbitrary offset — the JS mirror of phDay().
  const dayAtOffset = (offsetMinutes, d = new Date()) => {
    const t = new Date(d.getTime() + offsetMinutes * 60000);
    return t.getUTCFullYear() * 10000 + (t.getUTCMonth() + 1) * 100 + t.getUTCDate();
  };

  afterEach(async () => {
    // Leave the DB on the default so later suites see stock behaviour.
    await testEnv.withSecurityRulesDisabled((ctx) =>
      ctx.firestore().collection("settings").doc("general").delete()
    );
  });

  const setOffset = (tzOffsetMinutes) =>
    testEnv.withSecurityRulesDisabled((ctx) =>
      ctx.firestore().collection("settings").doc("general").set({ tzOffsetMinutes })
    );

  it("falls back to +8 when settings/general is absent", async () => {
    await assertSucceeds(
      as("cashier").collection("drawer_state").doc("state")
        .set({ lastSaleDay: phDay() }, { merge: true })
    );
  });

  it("accepts today's day for the configured offset", async () => {
    await setOffset(540); // Asia/Tokyo
    await assertSucceeds(
      as("cashier").collection("drawer_state").doc("state")
        .set({ lastSaleDay: dayAtOffset(540) }, { merge: true })
    );
  });

  it("rejects a day computed with the OLD offset when they differ", async () => {
    await setOffset(540);
    const tokyoDay = dayAtOffset(540);
    const phDayValue = phDay();
    // The two offsets only disagree in the hour before PH midnight; when they
    // agree there is nothing to assert, so pass trivially rather than skip
    // (an arrow function has no Mocha `this` to call skip() on).
    if (tokyoDay === phDayValue) return;
    await assertFails(
      as("cashier").collection("drawer_state").doc("state")
        .set({ lastSaleDay: phDayValue }, { merge: true })
    );
  });

  it("still rejects a future day", async () => {
    await setOffset(540);
    await assertFails(
      as("cashier").collection("drawer_state").doc("state")
        .set({ lastSaleDay: dayAtOffset(540) + 1 }, { merge: true })
    );
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd tools/firestore-rules-test && npm test`
Expected: the `settings/general` validation tests FAIL (an out-of-range offset is currently accepted — the existing rule allows any admin write), and the Tokyo-offset `drawer_state` test FAILS (`phDay()` is still hardcoded to +8).

- [ ] **Step 3: Write the implementation**

In `firestore.rules`, replace the `phDay()` helper (lines 43–48) with:

```
    // Shop timezone offset, in minutes east of UTC, from settings/general.
    // Falls back to +8h (Asia/Manila) when the doc or the field is absent —
    // that fallback is what keeps a pre-seed database and older app versions
    // behaving exactly as before.
    function shopOffsetMinutes() {
      return exists(/databases/$(database)/documents/settings/general)
        ? get(/databases/$(database)/documents/settings/general).data.get('tzOffsetMinutes', 480)
        : 480;
    }

    // The shop's business day as a yyyymmdd int, for drawer_state math.
    // Must match shopDayInt() on mobile and web for the same instant.
    function phDay() {
      let t = request.time + duration.value(shopOffsetMinutes(), 'm');
      return t.year() * 10000 + t.month() * 100 + t.day();
    }
```

Add a validator near the other helpers:

```
    // settings/general is a shared bucket; only the timezone keys are
    // validated. A bad tzOffsetMinutes would break the business day on every
    // device, and the rules themselves read this value.
    function validGeneralSettings() {
      let d = request.resource.data;
      return (!d.keys().hasAny(['tzOffsetMinutes']) ||
              (d.tzOffsetMinutes is int &&
               d.tzOffsetMinutes >= -720 &&
               d.tzOffsetMinutes <= 840)) &&
             (!d.keys().hasAny(['timezoneId']) || d.timezoneId is string);
    }
```

and tighten the settings write rule (lines 292–305), leaving the read rule and the `sale_counters` exception untouched:

```
      // Only admin can modify settings
      allow write: if isAdmin() && isActiveUser() &&
        (settingId != 'general' || validGeneralSettings());
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd tools/firestore-rules-test && npm test`
Expected: the full rules suite PASSES, including the pre-existing `/drawer_state` and `/settings` describes.

- [ ] **Step 5: Commit**

```bash
git add firestore.rules tools/firestore-rules-test/test/rules.test.js
git commit -m "feat(timezone): rules read the configured shop offset, validate settings/general"
```

---

## Task 13: Seed script and rollout checklist

**Files:**
- Create: `scripts/seed-shop-timezone.mjs`
- Create: `scripts/seed-shop-timezone-lib.mjs`
- Test: `scripts/seed-shop-timezone-lib.test.mjs`
- Modify: `scripts/README.md`

**Interfaces:**
- Consumes: `settings/general` document shape.
- Produces: `buildSeedPayload({ timezoneId, offsetMinutes })` and an idempotent `seedShopTimezone(db, payload, { dryRun })`.

Follow the conventions of the existing scripts in this directory (`backfill-product-skus.mjs` and its `-lib` / `-lib.test.mjs` split): pure logic in the `-lib` file with Node tests, `firebase-admin` init and `--dry-run` handling in the runner.

- [ ] **Step 1: Write the failing test**

Create `scripts/seed-shop-timezone-lib.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildSeedPayload, DEFAULT_SEED } from './seed-shop-timezone-lib.mjs';

test('defaults to Asia/Manila at +480', () => {
  assert.equal(DEFAULT_SEED.timezoneId, 'Asia/Manila');
  assert.equal(DEFAULT_SEED.tzOffsetMinutes, 480);
});

test('builds a payload with both keys', () => {
  const p = buildSeedPayload({ timezoneId: 'Asia/Tokyo', offsetMinutes: 540 });
  assert.equal(p.timezoneId, 'Asia/Tokyo');
  assert.equal(p.tzOffsetMinutes, 540);
});

test('rejects an out-of-range offset', () => {
  assert.throws(() => buildSeedPayload({ timezoneId: 'X', offsetMinutes: 99999 }));
});

test('rejects a non-integer offset', () => {
  assert.throws(() => buildSeedPayload({ timezoneId: 'X', offsetMinutes: 8.5 }));
});

test('rejects an empty timezone id', () => {
  assert.throws(() => buildSeedPayload({ timezoneId: '', offsetMinutes: 480 }));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test scripts/seed-shop-timezone-lib.test.mjs`
Expected: FAIL — module not found.

- [ ] **Step 3: Write the implementation**

Create `scripts/seed-shop-timezone-lib.mjs` exporting `DEFAULT_SEED = { timezoneId: 'Asia/Manila', tzOffsetMinutes: 480 }` and `buildSeedPayload({ timezoneId, offsetMinutes })`, which validates `Number.isInteger(offsetMinutes)`, the -720..840 range, and a non-empty string id, then returns `{ timezoneId, tzOffsetMinutes: offsetMinutes }`.

Create `scripts/seed-shop-timezone.mjs`: initialise `firebase-admin` the way the neighbouring scripts do, accept optional `--timezone=<id> --offset=<minutes>` (defaulting to `DEFAULT_SEED`) and `--dry-run`, read `settings/general` first, print what it would write, and — unless dry-running — `set(payload, { merge: true })`. Merge, not overwrite: `general` is shared with future settings. Print the resulting document and exit non-zero on failure.

Add a short entry to `scripts/README.md` describing the script and noting it is idempotent.

- [ ] **Step 4: Run tests to verify they pass**

Run: `node --test scripts/seed-shop-timezone-lib.test.mjs`
Expected: PASS (5 tests).

Run: `node scripts/seed-shop-timezone.mjs --dry-run`
Expected: prints the payload it would write and makes no change. **Do not run it against production without the user's go-ahead** — see the rollout below.

- [ ] **Step 5: Commit**

```bash
git add scripts/seed-shop-timezone.mjs scripts/seed-shop-timezone-lib.mjs scripts/seed-shop-timezone-lib.test.mjs scripts/README.md
git commit -m "chore(timezone): idempotent settings/general seed script"
```

- [ ] **Step 6: Full verification sweep**

Run each and confirm the output before claiming the feature done:

```bash
flutter analyze
flutter test
cd web_admin && npm run typecheck && npm run test && npm run build && cd ..
cd tools/firestore-rules-test && npm test && cd ../..
node --test scripts/seed-shop-timezone-lib.test.mjs
```

- [ ] **Step 7: Rollout (each step needs the user's explicit go-ahead)**

These touch production. Confirm before each, per CLAUDE.md.

1. Seed: `node scripts/seed-shop-timezone.mjs` (idempotent; safe to re-run).
2. Deploy rules: `firebase deploy --only firestore:rules`. Safe in either order relative to step 1 thanks to the 480 fallback.
3. Deploy web admin: build and `firebase deploy --only hosting`. Smoke-test the dashboard, a report preset, activity-log grouping, and the new settings page.
4. Ship mobile in the next APK (`flutter build apk --release` + App Distribution). Note in the release log that this build is required before anyone changes the shop timezone away from Asia/Manila.

---

## Notes for the executor

- **The instant/wall distinction is the whole feature.** Before writing any date expression, ask which one you are holding. A wall value that reaches `Timestamp.fromDate` or a Firestore query bound is a silent, hard-to-spot bug that only shows up outside PH.
- **Nothing should change on a PH device.** If a test expectation has to move by a day for a PH-local input, the implementation is wrong, not the test.
- **The rules are the referee.** `businessDayInt` on mobile, `phDayInt` on web, and `phDay()` in the rules must agree for the same instant. Task 5's and Task 9's cross-checks exist to keep that true.
