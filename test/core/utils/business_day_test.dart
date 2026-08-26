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
