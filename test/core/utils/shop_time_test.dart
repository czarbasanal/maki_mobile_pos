import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/core/utils/shop_timezones.dart';

void main() {
  const ph = 480; // Asia/Manila
  const est = -300; // UTC-5, a "device in the US" stand-in

  group('shopTimeOf', () {
    test('shifts an instant into shop wall time', () {
      final instant = DateTime.utc(2026, 8, 26, 15, 30);
      final wall = shopTimeOf(instant, ph);
      expect(wall.year, 2026);
      expect(wall.month, 8);
      expect(wall.day, 26);
      expect(wall.hour, 23);
      expect(wall.minute, 30);
    });

    test('is independent of the DateTime the caller hands in', () {
      // Same instant expressed two ways must produce the same wall time.
      final utc = DateTime.utc(2026, 8, 26, 15, 30);
      final shifted = utc.add(const Duration(hours: 3)).subtract(const Duration(hours: 3));
      expect(shopTimeOf(shifted, ph), shopTimeOf(utc, ph));
    });

    test('crosses the day boundary at shop midnight, not device midnight', () {
      // 16:00 UTC on the 25th is 00:00 of the 26th in PH.
      final instant = DateTime.utc(2026, 8, 25, 16, 0);
      expect(shopDayInt(instant, ph), 20260826);
      // The same instant is still the 25th for a UTC-5 device.
      expect(shopDayInt(instant, est), 20260825);
    });
  });

  group('instantOf', () {
    test('round-trips with shopTimeOf', () {
      final instant = DateTime.utc(2026, 8, 26, 15, 30, 45, 123);
      expect(instantOf(shopTimeOf(instant, ph), ph), instant);
      expect(instantOf(shopTimeOf(instant, est), est), instant);
    });

    test('returns a UTC instant for a shop wall time', () {
      final wall = shopWall(2026, 8, 26); // shop midnight
      final instant = instantOf(wall, ph);
      expect(instant.isUtc, isTrue);
      expect(instant, DateTime.utc(2026, 8, 25, 16, 0));
    });
  });

  group('shopDayInt', () {
    test('matches the rules yyyymmdd shape', () {
      expect(shopDayInt(DateTime.utc(2026, 1, 2, 4, 0), ph), 20260102);
    });

    test('handles year boundaries', () {
      // 16:00 UTC Dec 31 is 00:00 Jan 1 in PH.
      expect(shopDayInt(DateTime.utc(2026, 12, 31, 16, 0), ph), 20270101);
    });

    test('handles a negative offset', () {
      // 02:00 UTC Jan 1 is 21:00 Dec 31 at UTC-5.
      expect(shopDayInt(DateTime.utc(2027, 1, 1, 2, 0), est), 20261231);
    });
  });

  group('shopDateOf', () {
    test('truncates to shop midnight and stays a wall value', () {
      final d = shopDateOf(DateTime.utc(2026, 8, 26, 15, 30), ph);
      expect(d, shopWall(2026, 8, 26));
      expect(d.isUtc, isTrue);
      expect(d.hour, 0);
    });
  });

  group('ShopTimeConfig + extensions', () {
    setUp(() => ShopTimeConfig.offsetMinutes = kDefaultShopOffsetMinutes);

    test('defaults to Asia/Manila', () {
      expect(ShopTimeConfig.offsetMinutes, 480);
      expect(ShopTimeConfig.timezoneId, 'Asia/Manila');
    });

    test('inShopTime uses the ambient offset', () {
      ShopTimeConfig.offsetMinutes = est;
      expect(DateTime.utc(2026, 8, 26, 15, 30).inShopTime.hour, 10);
    });

    test('asShopInstant inverts inShopTime', () {
      final instant = DateTime.utc(2026, 8, 26, 15, 30);
      expect(instant.inShopTime.asShopInstant, instant);
    });
  });

  group('kShopTimezones', () {
    test('contains Asia/Manila at +480 as the default', () {
      final manila = shopTimezoneById(kDefaultShopTimezoneId);
      expect(manila, isNotNull);
      expect(manila!.offsetMinutes, kDefaultShopOffsetMinutes);
    });

    test('every offset is within the supported range', () {
      for (final tz in kShopTimezones) {
        expect(tz.offsetMinutes, inInclusiveRange(-720, 840));
      }
    });

    test('ids are unique', () {
      final ids = kShopTimezones.map((t) => t.id).toSet();
      expect(ids.length, kShopTimezones.length);
    });

    test('unknown id returns null', () {
      expect(shopTimezoneById('Mars/Olympus'), isNull);
    });
  });
}
