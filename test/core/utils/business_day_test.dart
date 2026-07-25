import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/business_day.dart';

void main() {
  group('nextMidnightAfter', () {
    test('mid-day rolls to the next 00:00', () {
      final t = DateTime(2026, 7, 24, 13, 45, 30);
      expect(nextMidnightAfter(t), DateTime(2026, 7, 25));
    });

    test('23:59:59 rolls to the next day midnight', () {
      final t = DateTime(2026, 7, 24, 23, 59, 59);
      expect(nextMidnightAfter(t), DateTime(2026, 7, 25));
    });

    test('month boundary', () {
      final t = DateTime(2026, 7, 31, 22, 0);
      expect(nextMidnightAfter(t), DateTime(2026, 8, 1));
    });

    test('year boundary', () {
      final t = DateTime(2026, 12, 31, 23);
      expect(nextMidnightAfter(t), DateTime(2027, 1, 1));
    });
  });

  group('businessDateOf', () {
    test('truncates time-of-day', () {
      final t = DateTime(2026, 7, 24, 13, 45, 30, 500);
      expect(businessDateOf(t), DateTime(2026, 7, 24));
    });

    test('midnight is unchanged', () {
      final t = DateTime(2026, 7, 24);
      expect(businessDateOf(t), DateTime(2026, 7, 24));
    });
  });

  group('businessDayInt', () {
    test('encodes yyyymmdd', () {
      expect(businessDayInt(DateTime(2026, 7, 25)), 20260725);
    });

    test('pads single-digit month and day', () {
      expect(businessDayInt(DateTime(2026, 1, 5)), 20260105);
    });

    test('ignores time-of-day', () {
      expect(businessDayInt(DateTime(2026, 7, 25, 23, 59)), 20260725);
    });
  });
}
