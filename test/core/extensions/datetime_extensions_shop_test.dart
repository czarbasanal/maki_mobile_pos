import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/extensions/datetime_extensions.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';

void main() {
  setUp(() => ShopTimeConfig.apply(
        timezoneId: kDefaultShopTimezoneId,
        offsetMinutes: kDefaultShopOffsetMinutes,
      ));

  tearDown(() => ShopTimeConfig.apply(
        timezoneId: kDefaultShopTimezoneId,
        offsetMinutes: kDefaultShopOffsetMinutes,
      ));

  test('isSameShopDay compares shop days, not device days', () {
    // 00:30 Aug 26 PH — a UTC-5 device would call this Aug 25.
    final instant = DateTime.utc(2026, 8, 25, 16, 30);
    final sameShopDay = DateTime.utc(2026, 8, 26, 5, 0); // 13:00 Aug 26 PH
    expect(instant.isSameShopDay(sameShopDay), isTrue);
  });

  test('startOfDay returns the instant of shop midnight', () {
    final instant = DateTime.utc(2026, 8, 26, 5, 0);
    expect(instant.startOfDay, DateTime.utc(2026, 8, 25, 16, 0));
  });

  test('endOfDay returns the instant of the last millisecond of the shop day',
      () {
    final instant = DateTime.utc(2026, 8, 26, 5, 0);
    expect(instant.endOfDay, DateTime.utc(2026, 8, 26, 15, 59, 59, 999));
  });

  test('a changed shop offset moves the day boundary', () {
    ShopTimeConfig.apply(timezoneId: 'Asia/Tokyo', offsetMinutes: 540);
    final instant = DateTime.utc(2026, 8, 26, 5, 0);
    expect(instant.startOfDay, DateTime.utc(2026, 8, 25, 15, 0)); // 00:00 JST
  });

  test('startOfMonth / endOfMonth are shop-month bounds as instants', () {
    final instant = DateTime.utc(2026, 8, 25, 16, 30); // Aug 26 00:30 PH
    expect(instant.startOfMonth, DateTime.utc(2026, 7, 31, 16, 0));
    expect(instant.endOfMonth, DateTime.utc(2026, 8, 31, 15, 59, 59, 999));
  });

  test('startOfWeek is the shop Monday midnight as an instant', () {
    final instant = DateTime.utc(2026, 8, 25, 16, 30); // Wed Aug 26 PH
    expect(instant.startOfWeek, DateTime.utc(2026, 8, 23, 16, 0)); // Aug 24 PH
  });

  test('endOfQuarter is the last millisecond of the shop quarter', () {
    final instant = DateTime.utc(2026, 8, 25, 16, 30); // Aug 26 PH -> Q3
    expect(instant.endOfQuarter, DateTime.utc(2026, 9, 30, 15, 59, 59, 999));
  });
}
