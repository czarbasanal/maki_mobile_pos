import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/business_day.dart';
import 'package:maki_mobile_pos/core/utils/report_date_range.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';

/// The window `todaysSalesSummaryProvider` asks the report use case for.
///
/// `businessDayProvider` hands back a shop WALL midnight (a UTC-flagged value
/// standing for shop-calendar fields, not a real instant). Turning that into a
/// query range has to go back through the offset — building the upper bound
/// with the plain `DateTime(...)` constructor instead silently mixes a wall
/// value with a device-local one, and the window lands hours off on any device
/// whose zone is not the shop's.
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
}
