import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/report_date_range.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/date_range_picker.dart';

void main() {
  const ph = kDefaultShopOffsetMinutes; // 480
  final now = shopWall(2026, 7, 1, 14, 30); // fixed shop wall anchor

  /// Expected instant for a shop wall boundary.
  DateTime at(DateTime wall) => instantOf(wall, ph);

  test('today = shop midnight..23:59:59.999 same shop day', () {
    final r = dateRangeForPreset(DateRangePreset.today, now, ph);
    expect(r.start, at(shopWall(2026, 7, 1)));
    expect(r.end, at(shopWall(2026, 7, 1, 23, 59, 59, 999)));
  });

  test('yesterday = the prior shop day', () {
    final r = dateRangeForPreset(DateRangePreset.yesterday, now, ph);
    expect(r.start, at(shopWall(2026, 6, 30)));
    expect(r.end, at(shopWall(2026, 6, 30, 23, 59, 59, 999)));
  });

  test('thisWeek starts on a Monday on/before now', () {
    final r = dateRangeForPreset(DateRangePreset.thisWeek, now, ph);
    final startWall = shopTimeOf(r.start, ph);
    expect(startWall.weekday, DateTime.monday);
    expect(startWall.isAfter(now), isFalse);
    expect(now.difference(startWall).inDays, lessThan(7));
  });

  test('thisMonth starts on the 1st', () {
    final r = dateRangeForPreset(DateRangePreset.thisMonth, now, ph);
    expect(r.start, at(shopWall(2026, 7, 1)));
  });

  test('lastMonth spans the whole previous month', () {
    final r = dateRangeForPreset(DateRangePreset.lastMonth, now, ph);
    expect(r.start, at(shopWall(2026, 6, 1)));
    expect(r.end, at(shopWall(2026, 6, 30, 23, 59, 59, 999)));
  });

  test('lastWeek spans the previous Monday..Sunday', () {
    final r = dateRangeForPreset(DateRangePreset.lastWeek, now, ph);
    // Jul 1 2026 is a Wednesday -> last week is Jun 22..Jun 28.
    expect(r.start, at(shopWall(2026, 6, 22)));
    expect(r.end, at(shopWall(2026, 6, 28, 23, 59, 59, 999)));
  });

  test('thisQuarter: July is Q3 -> starts July 1', () {
    final r = dateRangeForPreset(DateRangePreset.thisQuarter, now, ph);
    expect(r.start, at(shopWall(2026, 7, 1)));
  });

  test('thisYear starts Jan 1', () {
    final r = dateRangeForPreset(DateRangePreset.thisYear, now, ph);
    expect(r.start, at(shopWall(2026, 1, 1)));
  });

  test('custom falls back to today', () {
    final r = dateRangeForPreset(DateRangePreset.custom, now, ph);
    expect(r.start, at(shopWall(2026, 7, 1)));
  });

  group('shop-time boundaries', () {
    test('today spans the shop day as instants', () {
      final shopNow = shopWall(2026, 8, 26, 14, 0);
      final r = dateRangeForPreset(DateRangePreset.today, shopNow, ph);
      expect(r.start, DateTime.utc(2026, 8, 25, 16, 0)); // shop midnight
      expect(r.end, DateTime.utc(2026, 8, 26, 15, 59, 59, 999));
    });

    test('yesterday spans the previous shop day', () {
      final shopNow = shopWall(2026, 8, 26, 14, 0);
      final r = dateRangeForPreset(DateRangePreset.yesterday, shopNow, ph);
      expect(r.start, DateTime.utc(2026, 8, 24, 16, 0));
      expect(r.end, DateTime.utc(2026, 8, 25, 15, 59, 59, 999));
    });

    test('thisMonth starts at shop midnight on the 1st', () {
      final shopNow = shopWall(2026, 8, 26, 14, 0);
      final r = dateRangeForPreset(DateRangePreset.thisMonth, shopNow, ph);
      expect(r.start, DateTime.utc(2026, 7, 31, 16, 0)); // Aug 1 00:00 PH
    });

    test('the returned bounds are instants, not wall values', () {
      final r =
          dateRangeForPreset(DateRangePreset.today, shopWall(2026, 8, 26), ph);
      // Shop midnight is 16:00 UTC the day before — a wall value would read 00:00.
      expect(r.start.hour, 16);
    });

    test('a different shop offset moves the boundary', () {
      final r = dateRangeForPreset(
          DateRangePreset.today, shopWall(2026, 8, 26, 14, 0), -300);
      expect(r.start, DateTime.utc(2026, 8, 26, 5, 0)); // 00:00 at UTC-5
    });

    test('an instant one millisecond before the end is inside the range', () {
      final r =
          dateRangeForPreset(DateRangePreset.today, shopWall(2026, 8, 26), ph);
      final lastMoment = r.end;
      expect(lastMoment.isBefore(DateTime.utc(2026, 8, 26, 16, 0)), isTrue);
    });
  });

  group('picked-day bounds', () {
    test('a picked day becomes the shop day it names', () {
      final picked = DateTime(2026, 8, 26); // device-local, fields = the day
      expect(shopDayStartInstant(picked, ph), DateTime.utc(2026, 8, 25, 16, 0));
      expect(shopDayEndInstant(picked, ph),
          DateTime.utc(2026, 8, 26, 15, 59, 59, 999));
    });

    test('the picked day\'s own zone flag is ignored — only its fields matter',
        () {
      expect(shopDayStartInstant(DateTime.utc(2026, 8, 26), ph),
          shopDayStartInstant(DateTime(2026, 8, 26), ph));
    });
  });
}
