import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/week_range.dart';

void main() {
  group('weekToDate', () {
    test('Monday — daysElapsed 1, start equals today midnight', () {
      // 2026-05-04 is a Monday.
      final now = DateTime(2026, 5, 4, 14, 30);
      final w = weekToDate(now);
      expect(w.daysElapsed, 1);
      expect(w.start, DateTime(2026, 5, 4));
      expect(w.end, now);
    });

    test('Wednesday — daysElapsed 3, start is the Monday two days earlier',
        () {
      final now = DateTime(2026, 5, 6, 9, 0); // Wed
      final w = weekToDate(now);
      expect(w.daysElapsed, 3);
      expect(w.start, DateTime(2026, 5, 4));
    });

    test('Sunday — daysElapsed 7, start is the Monday six days earlier', () {
      final now = DateTime(2026, 5, 10, 23, 59); // Sun
      final w = weekToDate(now);
      expect(w.daysElapsed, 7);
      expect(w.start, DateTime(2026, 5, 4));
    });

    test('week start crosses a month boundary', () {
      // 2026-08-04 is a Tuesday → Monday is 2026-08-03.
      // Trying a case where Monday is in a different month than today:
      // 2026-09-02 is a Wednesday → Monday is 2026-08-31.
      final now = DateTime(2026, 9, 2, 8, 0);
      final w = weekToDate(now);
      expect(w.daysElapsed, 3);
      expect(w.start, DateTime(2026, 8, 31));
    });

    test('week start crosses a year boundary', () {
      // 2026-01-01 is a Thursday (weekday 4) → Monday is 2025-12-29.
      final now = DateTime(2026, 1, 1, 12, 0);
      final w = weekToDate(now);
      expect(w.daysElapsed, 4);
      expect(w.start, DateTime(2025, 12, 29));
    });

    test('start has hour/minute zeroed even when now has clock time', () {
      final now = DateTime(2026, 5, 7, 23, 45, 12);
      final w = weekToDate(now);
      expect(w.start.hour, 0);
      expect(w.start.minute, 0);
      expect(w.start.second, 0);
    });
  });

  group('monthToDate', () {
    test('1st of the month — daysElapsed 1, start equals today midnight', () {
      final now = DateTime(2026, 5, 1, 14, 30);
      final m = monthToDate(now);
      expect(m.daysElapsed, 1);
      expect(m.start, DateTime(2026, 5, 1));
      expect(m.end, now);
    });

    test('mid-month — daysElapsed equals day-of-month', () {
      final now = DateTime(2026, 5, 15, 9, 0);
      final m = monthToDate(now);
      expect(m.daysElapsed, 15);
      expect(m.start, DateTime(2026, 5, 1));
    });

    test('last day of a 31-day month — daysElapsed 31', () {
      final now = DateTime(2026, 5, 31, 23, 59);
      final m = monthToDate(now);
      expect(m.daysElapsed, 31);
      expect(m.start, DateTime(2026, 5, 1));
    });

    test('last day of February (non-leap) — daysElapsed 28', () {
      final now = DateTime(2026, 2, 28, 12, 0);
      final m = monthToDate(now);
      expect(m.daysElapsed, 28);
      expect(m.start, DateTime(2026, 2, 1));
    });

    test('start has hour/minute zeroed even when now has clock time', () {
      final now = DateTime(2026, 5, 7, 23, 45, 12);
      final m = monthToDate(now);
      expect(m.start.hour, 0);
      expect(m.start.minute, 0);
      expect(m.start.second, 0);
    });
  });

  group('avgDailyFromGross', () {
    test('divides gross by days elapsed', () {
      expect(avgDailyFromGross(7000, 7), 1000);
      expect(avgDailyFromGross(1500, 3), 500);
    });

    test('returns 0 when no days elapsed', () {
      expect(avgDailyFromGross(1000, 0), 0);
      expect(avgDailyFromGross(1000, -1), 0);
    });

    test('handles zero gross', () {
      expect(avgDailyFromGross(0, 5), 0);
    });
  });
}
