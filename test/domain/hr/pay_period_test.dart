// Port of web_admin/src/domain/hr/payPeriod.test.ts — vectors verbatim, plus
// the month-boundary case. All dates are LOCAL 'YYYY-MM-DD' strings; the
// implementation must step dates via DateTime.utc internally so a CI machine
// in any timezone produces identical strings.
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/hr/pay_period.dart';

void main() {
  group('payPeriodFor', () {
    test('snaps back to the most recent Monday for weekStartDay=1', () {
      // 2026-07-22 is a Wednesday.
      final p = payPeriodFor(DateTime(2026, 7, 22), 1);
      expect(p.start, '2026-07-20');
      expect(p.end, '2026-07-26');
      expect(p.dates, hasLength(7));
      expect(p.dates[2], '2026-07-22');
    });

    test('anchor already on the start day stays put', () {
      final p = payPeriodFor(DateTime(2026, 7, 20), 1); // a Monday
      expect(p.start, '2026-07-20');
    });

    test('handles Sunday start (weekStartDay=7)', () {
      final p = payPeriodFor(DateTime(2026, 7, 22), 7);
      expect(p.start, '2026-07-19');
      expect(p.end, '2026-07-25');
    });

    test('spans a year boundary', () {
      final p = payPeriodFor(DateTime(2026, 1, 1), 1); // Thu 2026-01-01
      expect(p.start, '2025-12-29');
      expect(p.end, '2026-01-04');
    });

    test('spans a month boundary', () {
      final p = payPeriodFor(DateTime(2026, 8, 1), 1); // Sat 2026-08-01
      expect(p.start, '2026-07-27');
      expect(p.end, '2026-08-02');
    });

    test('ignores the anchor time-of-day', () {
      final p = payPeriodFor(DateTime(2026, 7, 22, 23, 59), 1);
      expect(p.start, '2026-07-20');
    });
  });

  group('shiftPeriod', () {
    test('moves whole weeks in both directions', () {
      final p = payPeriodFor(DateTime(2026, 7, 22), 1);
      expect(shiftPeriod(p, -1).start, '2026-07-13');
      expect(shiftPeriod(p, 1).start, '2026-07-27');
      expect(shiftPeriod(p, 1).end, '2026-08-02');
      expect(shiftPeriod(p, 1).dates, hasLength(7));
    });
  });

  group('weekdayLabel', () {
    test('labels ISO 1..7 Monday..Sunday, blank for unknown', () {
      expect(weekdayLabel(1), 'Monday');
      expect(weekdayLabel(7), 'Sunday');
      expect(weekdayLabel(0), '');
      expect(weekdayLabel(8), '');
    });
  });
}
