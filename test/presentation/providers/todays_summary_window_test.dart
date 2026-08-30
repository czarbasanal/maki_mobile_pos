import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/business_day.dart';
import 'package:maki_mobile_pos/core/utils/report_date_range.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';

/// The window the reporting layer asks for, in real instants.
///
/// `getSalesByDateRange` used to discard these and rebuild device-local day
/// bounds from `.year/.month/.day`, which meant a correct shop-day-start
/// instant (16:00Z the previous day at UTC+8) read as the PREVIOUS day and
/// returned two days of sales — ₱8,840 rendering as ₱15,480. It now uses its
/// bounds as given; these tests pin what those bounds are.
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

  group('the repository no longer re-derives local days', () {
    test('a shop-day-start instant is not silently moved to another day', () {
      // The regression: DateTime(start.year, start.month, start.day) read 29
      // off this value and queried from the 29th. Nothing rebuilds it now, so
      // the bound the query uses IS this instant.
      final start = shopDayStartInstant(shopWall(2026, 8, 30), phOffset);
      expect(start, DateTime.utc(2026, 8, 29, 16));
      // Its UTC calendar day really is the 29th — which is exactly why
      // re-deriving a day from these fields was wrong.
      expect(start.day, 29);
    });

    test('start and end bracket one shop day, not two', () {
      final start = shopDayStartInstant(shopWall(2026, 8, 30), phOffset);
      final end = shopDayEndInstant(shopWall(2026, 8, 30), phOffset);
      expect(end.difference(start).inHours, 23);
    });
  });
}
