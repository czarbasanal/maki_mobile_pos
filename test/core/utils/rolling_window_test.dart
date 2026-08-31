import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/core/utils/week_range.dart';

void main() {
  const phOffset = 480; // UTC+8

  group('rollingDays', () {
    test('covers the last 30 COMPLETED days, ending yesterday', () {
      // Shop day is 2026-09-01; the window is Aug 2 through Aug 31.
      final window = rollingDays(shopWall(2026, 9, 1), 30, phOffset);

      expect(window.days, 30);
      expect(window.start, instantOf(shopWall(2026, 8, 2), phOffset));
      expect(window.end,
          instantOf(shopWall(2026, 8, 31, 23, 59, 59, 999), phOffset));
    });

    test("today never leaks in — it is still being earned", () {
      final today = shopWall(2026, 9, 1);
      final window = rollingDays(today, 30, phOffset);

      expect(window.end.isBefore(instantOf(today, phOffset)), isTrue);
    });

    test('rolls back across a month and a year boundary', () {
      final window = rollingDays(shopWall(2026, 1, 5), 30, phOffset);
      expect(window.start, instantOf(shopWall(2025, 12, 6), phOffset));
    });

    test('bounds are SHOP instants, not the device\'s local days', () {
      // The whole reason this helper takes an offset: getSalesByDateRange uses
      // its bounds as given, so a local-constructor date would shift the whole
      // window by the handset's distance from shop time.
      final window = rollingDays(shopWall(2026, 9, 1), 30, phOffset);
      expect(window.start.isUtc, isTrue);
      expect(window.end.isUtc, isTrue);
      // 30 whole days between the two ends.
      expect(window.end.difference(window.start).inDays, 29);
    });

    test('still supports a 7-day window', () {
      final window = rollingDays(shopWall(2026, 9, 1), 7, phOffset);
      expect(window.days, 7);
      expect(window.start, instantOf(shopWall(2026, 8, 25), phOffset));
    });
  });

  group('avgDailyFromGross', () {
    test('divides by the whole window, so a closed day counts as zero', () {
      // A quiet or closed day is a real 0 day and stays in the average.
      expect(avgDailyFromGross(30000, 30), 1000);
    });

    test('guards against a zero divisor', () {
      expect(avgDailyFromGross(500, 0), 0);
    });
  });
}
