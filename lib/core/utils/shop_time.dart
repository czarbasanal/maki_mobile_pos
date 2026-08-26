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
