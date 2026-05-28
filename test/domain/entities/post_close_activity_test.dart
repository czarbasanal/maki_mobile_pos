import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';

DailyClosingEntity _closing({
  double gross = 1000,
  int salesCount = 5,
  double cashSales = 600,
  double cashExpenses = 100,
  double countedCash = 2500,
}) =>
    DailyClosingEntity(
      id: '2026-05-28',
      businessDate: DateTime(2026, 5, 28),
      grossSales: gross,
      netSales: gross,
      totalDiscounts: 0,
      cashSales: cashSales,
      nonCashSales: gross - cashSales,
      gcashSales: 0,
      mayaSales: 0,
      totalExpenses: cashExpenses,
      cashExpenses: cashExpenses,
      salmonReceivable: 0,
      openingFloat: 2000,
      expectedCash: 2000 + cashSales - cashExpenses,
      countedCash: countedCash,
      variance: 0,
      salesCount: salesCount,
      voidedCount: 0,
      closedBy: 'u',
      closedByName: 'U',
      closedAt: DateTime(2026, 5, 28, 21, 30),
    );

DailyClosingDraft _draft({
  double gross = 1000,
  int salesCount = 5,
  double cashSales = 600,
  double cashExpenses = 100,
}) =>
    DailyClosingDraft(
      businessDate: DateTime(2026, 5, 28),
      grossSales: gross,
      netSales: gross,
      totalDiscounts: 0,
      cashSales: cashSales,
      nonCashSales: gross - cashSales,
      gcashSales: 0,
      mayaSales: 0,
      totalExpenses: cashExpenses,
      cashExpenses: cashExpenses,
      salmonReceivable: 0,
      salesCount: salesCount,
      voidedCount: 0,
    );

void main() {
  group('PostCloseActivity.between', () {
    test('no change when the live draft matches the snapshot', () {
      final a = PostCloseActivity.between(
        closing: _closing(),
        current: _draft(),
      );
      expect(a.hasChanged, false);
      expect(a.isAdditional, false);
      expect(a.extraSales, 0);
      expect(a.grossDelta, 0);
      // Updated cash on hand equals the counted cash when nothing changed.
      expect(a.updatedCashOnHand, 2500);
    });

    test('detects additional cash sales and updates cash on hand', () {
      // 3 more sales, all cash: gross +240, cash sales +240.
      final a = PostCloseActivity.between(
        closing: _closing(
            gross: 1000, salesCount: 5, cashSales: 600, countedCash: 2500),
        current: _draft(gross: 1240, salesCount: 8, cashSales: 840),
      );
      expect(a.hasChanged, true);
      expect(a.isAdditional, true);
      expect(a.extraSales, 3);
      expect(a.grossDelta, 240);
      expect(a.cashSalesDelta, 240);
      expect(a.cashExpensesDelta, 0);
      // 2500 counted + 240 cash collected after close = 2740.
      expect(a.updatedCashOnHand, 2740);
    });

    test('non-cash post-close sale changes gross but not cash on hand', () {
      // 1 more sale, paid via GCash: gross +300, cash sales unchanged.
      final a = PostCloseActivity.between(
        closing: _closing(gross: 1000, salesCount: 5, cashSales: 600),
        current: _draft(gross: 1300, salesCount: 6, cashSales: 600),
      );
      expect(a.hasChanged, true);
      expect(a.isAdditional, true);
      expect(a.cashSalesDelta, 0);
      expect(a.updatedCashOnHand, 2500); // unchanged drawer cash
    });

    test('post-close cash expense reduces cash on hand even with no new sale',
        () {
      final a = PostCloseActivity.between(
        closing: _closing(cashExpenses: 100, countedCash: 2500),
        current: _draft(cashExpenses: 150),
      );
      expect(a.hasChanged, true);
      expect(a.isAdditional, false);
      expect(a.cashExpensesDelta, 50);
      expect(a.updatedCashOnHand, 2450); // 2500 - 50
    });

    test('detects a reduction (void after close) as a change, not additional',
        () {
      final a = PostCloseActivity.between(
        closing: _closing(gross: 1000, salesCount: 5, cashSales: 600),
        current: _draft(gross: 800, salesCount: 4, cashSales: 400),
      );
      expect(a.hasChanged, true);
      expect(a.isAdditional, false);
      expect(a.extraSales, -1);
      expect(a.grossDelta, -200);
      expect(a.updatedCashOnHand, 2300); // 2500 - 200 cash reversed
    });

    test('ignores sub-cent floating point noise', () {
      final a = PostCloseActivity.between(
        closing: _closing(gross: 1000, cashSales: 600),
        current: _draft(gross: 1000.0001, cashSales: 600.0001),
      );
      expect(a.hasChanged, false);
    });
  });
}
