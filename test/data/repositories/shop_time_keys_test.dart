import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/data/repositories/daily_closing_repository_impl.dart';
import 'package:maki_mobile_pos/data/repositories/sale_repository_impl.dart';

void main() {
  const ph = 480;
  const est = -300;

  group('SaleRepositoryImpl.dateKeyFor', () {
    test('formats YYYYMMDD in shop time', () {
      expect(SaleRepositoryImpl.dateKeyFor(DateTime.utc(2026, 8, 26, 5, 0), ph), '20260826');
    });

    test('zero-pads month and day', () {
      expect(SaleRepositoryImpl.dateKeyFor(DateTime.utc(2026, 1, 2, 5, 0), ph), '20260102');
    });

    test('an instant after shop midnight uses the new shop day', () {
      // 16:30 UTC Aug 25 == 00:30 Aug 26 PH.
      expect(SaleRepositoryImpl.dateKeyFor(DateTime.utc(2026, 8, 25, 16, 30), ph), '20260826');
    });

    test('agrees with businessDayInt for the same instant', () {
      final instant = DateTime.utc(2026, 8, 25, 16, 30);
      expect(
        SaleRepositoryImpl.dateKeyFor(instant, ph),
        shopDayInt(instant, ph).toString(),
      );
    });

    test('follows a non-PH shop offset', () {
      expect(SaleRepositoryImpl.dateKeyFor(DateTime.utc(2026, 8, 26, 1, 0), est), '20260825');
    });
  });

  group('DailyClosingRepositoryImpl.docIdFor', () {
    test('formats yyyy-MM-dd from a shop wall date', () {
      expect(DailyClosingRepositoryImpl.docIdFor(shopWall(2026, 8, 26)), '2026-08-26');
    });

    test('zero-pads', () {
      expect(DailyClosingRepositoryImpl.docIdFor(shopWall(2026, 1, 2)), '2026-01-02');
    });
  });

  group('shop-day query bounds', () {
    test('span exactly the 24h of a shop day, as instants', () {
      final start = instantOf(shopWall(2026, 8, 26), ph);
      final end = instantOf(shopWall(2026, 8, 26, 23, 59, 59, 999), ph);
      expect(start, DateTime.utc(2026, 8, 25, 16, 0));
      expect(end.difference(start), const Duration(hours: 24) - const Duration(milliseconds: 1));
    });
  });
}
