import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';

DailyClosingEntity _closing({double gross = 1000, int salesCount = 5}) =>
    DailyClosingEntity(
      id: '2026-05-28',
      businessDate: DateTime(2026, 5, 28),
      grossSales: gross,
      netSales: gross,
      totalDiscounts: 0,
      cashSales: gross,
      nonCashSales: 0,
      totalExpenses: 0,
      cashExpenses: 0,
      openingFloat: 0,
      expectedCash: gross,
      countedCash: gross,
      variance: 0,
      salesCount: salesCount,
      voidedCount: 0,
      closedBy: 'u',
      closedByName: 'U',
      closedAt: DateTime(2026, 5, 28, 21, 30),
    );

void main() {
  group('PostCloseActivity.between', () {
    test('no change when live figures match the snapshot', () {
      final a = PostCloseActivity.between(
        closing: _closing(gross: 1000, salesCount: 5),
        currentSalesCount: 5,
        currentGross: 1000,
      );
      expect(a.hasChanged, false);
      expect(a.isAdditional, false);
      expect(a.extraSales, 0);
      expect(a.grossDelta, 0);
    });

    test('detects additional sales recorded after close', () {
      final a = PostCloseActivity.between(
        closing: _closing(gross: 1000, salesCount: 5),
        currentSalesCount: 8,
        currentGross: 1240,
      );
      expect(a.hasChanged, true);
      expect(a.isAdditional, true);
      expect(a.extraSales, 3);
      expect(a.grossDelta, 240);
    });

    test('detects a reduction (e.g. a void after close) as a change, '
        'but not as additional', () {
      final a = PostCloseActivity.between(
        closing: _closing(gross: 1000, salesCount: 5),
        currentSalesCount: 4,
        currentGross: 800,
      );
      expect(a.hasChanged, true);
      expect(a.isAdditional, false);
      expect(a.extraSales, -1);
      expect(a.grossDelta, -200);
    });

    test('ignores sub-cent floating point noise', () {
      final a = PostCloseActivity.between(
        closing: _closing(gross: 1000, salesCount: 5),
        currentSalesCount: 5,
        currentGross: 1000.0001,
      );
      expect(a.hasChanged, false);
    });
  });
}
