import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/report_csv.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';

DailyClosingEntity closing({
  required int day,
  double labor = 800,
  double fees = 260,
  Map<String, double> feesByType = const {},
  String? notes,
}) =>
    DailyClosingEntity(
      id: '2026-08-$day',
      businessDate: shopWall(2026, 8, day),
      grossSales: 7960,
      netSales: 7960,
      totalDiscounts: 0,
      cashSales: 8335,
      nonCashSales: 685,
      gcashSales: 400,
      mayaSales: 285,
      totalExpenses: 2844,
      cashExpenses: 2844,
      salmonReceivable: 0,
      laborRevenue: labor,
      feesRevenue: fees,
      feesByType: feesByType,
      openingFloat: 0,
      expectedCash: 5491,
      countedCash: 5491,
      variance: 0,
      salesCount: 21,
      voidedCount: 0,
      closedBy: 'u',
      closedByName: 'Belle',
      closedAt: DateTime.utc(2026, 8, day, 13, 24),
      notes: notes,
    );

void main() {
  group('buildClosingHistoryCsv', () {
    test('one row per closed day, newest first, with a header', () {
      final csv = buildClosingHistoryCsv(
        [closing(day: 31), closing(day: 30)],
        kDefaultShopOffsetMinutes,
      );
      final lines = csv.trim().split('\n');

      expect(lines.first, contains('Business Date'));
      expect(lines.length, 3);
      expect(lines[1], contains('2026-08-31'));
      expect(lines[2], contains('2026-08-30'));
    });

    test('carries every figure the expanded view shows', () {
      final csv = buildClosingHistoryCsv(
        [closing(day: 31)],
        kDefaultShopOffsetMinutes,
      );

      for (final expected in [
        '7960.00', // gross parts
        '800.00', // labor
        '260.00', // shop fees
        '8335.00', // cash sales
        '400.00', // gcash
        '2844.00', // cash expenses
        '5491.00', // expected / counted
        '4691.00', // to management = counted - labor
      ]) {
        expect(csv, contains(expected), reason: 'missing $expected');
      }
    });

    test('renders the close time in shop time, not the machine\'s', () {
      // 13:24Z is 21:24 in the shop. A device elsewhere must not change what
      // an exported record says happened.
      final csv = buildClosingHistoryCsv(
        [closing(day: 31)],
        kDefaultShopOffsetMinutes,
      );

      expect(csv, contains('21:24'));
    });

    test('an empty range still produces a header, not an empty file', () {
      final csv = buildClosingHistoryCsv([], kDefaultShopOffsetMinutes);
      expect(csv.trim().split('\n').length, 1);
      expect(csv, contains('Business Date'));
    });

    test('notes and absent notes both round-trip', () {
      final csv = buildClosingHistoryCsv(
        [closing(day: 31, notes: 'Short by 20, recounted')],
        kDefaultShopOffsetMinutes,
      );
      expect(csv, contains('Short by 20, recounted'));
    });
  });
}
