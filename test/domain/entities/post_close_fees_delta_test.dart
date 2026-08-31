import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';

DailyClosingEntity sealed({
  double labor = 400,
  double fees = 120,
  double grossSales = 1740,
  double cashSales = 2260,
  double cashExpenses = 0,
  double counted = 2260,
  int salesCount = 6,
}) =>
    DailyClosingEntity(
      id: '2026-08-27',
      businessDate: DateTime(2026, 8, 27),
      grossSales: grossSales,
      netSales: grossSales,
      totalDiscounts: 0,
      cashSales: cashSales,
      nonCashSales: 0,
      gcashSales: 0,
      mayaSales: 0,
      totalExpenses: cashExpenses,
      cashExpenses: cashExpenses,
      salmonReceivable: 0,
      laborRevenue: labor,
      feesRevenue: fees,
      openingFloat: 0,
      expectedCash: counted,
      countedCash: counted,
      variance: 0,
      salesCount: salesCount,
      voidedCount: 0,
      closedBy: 'u',
      closedByName: 'Bern',
      closedAt: DateTime(2026, 8, 27, 17, 5),
    );

DailyClosingDraft live({
  double labor = 550,
  double fees = 180,
  double grossSales = 4540,
  double cashSales = 5270,
  double cashExpenses = 0,
  int salesCount = 9,
}) =>
    DailyClosingDraft(
      businessDate: DateTime(2026, 8, 27),
      grossSales: grossSales,
      netSales: grossSales,
      totalDiscounts: 0,
      cashSales: cashSales,
      nonCashSales: 0,
      gcashSales: 0,
      mayaSales: 0,
      totalExpenses: cashExpenses,
      cashExpenses: cashExpenses,
      salmonReceivable: 0,
      laborRevenue: labor,
      feesRevenue: fees,
      salesCount: salesCount,
      voidedCount: 0,
    );

void main() {
  group('PostCloseActivity — shop fees', () {
    test('reports what fees moved after closing, and the updated total', () {
      final a = PostCloseActivity.between(closing: sealed(), current: live());

      expect(a.feesDelta, 60);            // 180 − 120
      expect(a.currentFeesRevenue, 180);
    });

    test('a day whose fees did not move reports a zero delta', () {
      final a = PostCloseActivity.between(
        closing: sealed(fees: 120),
        current: live(fees: 120),
      );

      expect(a.feesDelta, 0);
      expect(a.currentFeesRevenue, 120);
    });

    test('fees moving on their own still counts as drift', () {
      // Only the fees changed — nothing else. The After close card must still
      // render, or the money moved with nothing on screen to explain it.
      final a = PostCloseActivity.between(
        closing: sealed(),
        current: live(
          labor: 400, grossSales: 1740, cashSales: 2320, salesCount: 6,
        ),
      );

      expect(a.feesDelta, 60);
      expect(a.hasChanged, isTrue);
    });
  });
}
