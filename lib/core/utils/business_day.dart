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
