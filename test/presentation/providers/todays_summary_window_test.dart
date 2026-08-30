import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/business_day.dart';
import 'package:maki_mobile_pos/core/utils/report_date_range.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';

/// Shop-day bounds, and the trap underneath them.
///
/// These helpers return correct instants — but `getSalesByDateRange` does NOT
/// use the instants it is given: it rebuilds its own bounds with the
/// device-local `DateTime(...)` constructor from `.year/.month/.day`. So a
/// caller that hands it `shopDayStartInstant(...)` (16:00Z the previous day
/// for UTC+8) has that read as the PREVIOUS day, and gets two days of sales.
///
/// That is exactly what doubled the mobile dashboard against the web admin.
/// The helpers are right; the repository layering is what needs fixing, and
/// until it is, callers of that method must pass calendar fields instead.
void main() {
  const phOffset = 480; // UTC+8

  group('today window from a shop wall midnight', () {
    test('covers the whole shop day, both ends', () {
      // 17:07 PH on 2026-08-30, seen from a UTC+2 device.
      final now = DateTime.utc(2026, 8, 30, 9, 7);
      final day = businessDateOf(now, phOffset);

      final start = shopDayStartInstant(day, phOffset);
      final end = shopDayEndInstant(day, phOffset);

      // Shop 2026-08-30 runs 16:00Z on the 29th to 15:59:59.999Z on the 30th.
      expect(start, DateTime.utc(2026, 8, 29, 16));
      expect(end, DateTime.utc(2026, 8, 30, 15, 59, 59, 999));
      expect(now.isAfter(start) && now.isBefore(end), isTrue);
    });

    test('includes a sale rung up just after shop midnight', () {
      // 00:30 PH on the 30th — the case the local-constructor bound dropped,
      // because it started the window at 08:00 shop time instead.
      final earlySale = DateTime.utc(2026, 8, 29, 16, 30);
      final day = businessDateOf(earlySale, phOffset);

      final start = shopDayStartInstant(day, phOffset);
      final end = shopDayEndInstant(day, phOffset);

      expect(day, shopWall(2026, 8, 30));
      expect(!earlySale.isBefore(start) && !earlySale.isAfter(end), isTrue);
    });

    test('excludes the last sale of the previous shop day', () {
      final lateYesterday = DateTime.utc(2026, 8, 29, 15, 59, 59, 999);
      final day = businessDateOf(DateTime.utc(2026, 8, 30, 9), phOffset);

      expect(lateYesterday.isBefore(shopDayStartInstant(day, phOffset)), isTrue);
    });

    test('the bounds do not depend on the device zone', () {
      // Same instant, and the window must be identical however the device
      // would have rendered the calendar fields locally.
      final day = businessDateOf(DateTime.utc(2026, 8, 30, 9, 7), phOffset);
      expect(shopDayStartInstant(day, phOffset).isUtc, isTrue);
      expect(shopDayEndInstant(day, phOffset).isUtc, isTrue);
    });
  });

  group('the repository re-derives local day bounds (the trap)', () {
    // Mirrors getSalesByDateRange's normalization verbatim.
    ({DateTime start, DateTime end}) repoWindow(DateTime s, DateTime e) => (
          start: DateTime(s.year, s.month, s.day),
          end: DateTime(e.year, e.month, e.day, 23, 59, 59),
        );

    test('a shop wall midnight lands on the right local day', () {
      // What the providers pass today: the wall value's fields ARE the shop
      // calendar day, which is what the repository wants.
      final w = repoWindow(
        shopWall(2026, 8, 30),
        DateTime(2026, 8, 30, 23, 59, 59, 999),
      );
      expect(w.start.day, 30);
      expect(w.end.day, 30);
    });

    test('a true shop-day-start instant lands one day EARLY', () {
      // 2026-08-29T16:00Z is midnight on the 30th in shop time, but its UTC
      // calendar fields say the 29th — so the repository queries from the
      // 29th and the range covers two days.
      final start = shopDayStartInstant(shopWall(2026, 8, 30), phOffset);
      final end = shopDayEndInstant(shopWall(2026, 8, 30), phOffset);
      expect(start.day, 29);

      final w = repoWindow(start, end);
      expect(w.start.day, 29);
      expect(w.end.day, 30);
      // Two calendar days, which is how ₱8,840 rendered as ₱15,480.
      expect(w.end.difference(w.start).inDays, 1);
    });
  });
}
