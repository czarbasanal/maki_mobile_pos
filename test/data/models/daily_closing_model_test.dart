import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/daily_closing_model.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';

void main() {
  group('DailyClosingModel', () {
    final entity = DailyClosingEntity(
      id: '2026-05-28',
      businessDate: DateTime(2026, 5, 28),
      grossSales: 1000,
      netSales: 950,
      totalDiscounts: 50,
      cashSales: 600,
      nonCashSales: 350,
      totalExpenses: 300,
      cashExpenses: 220,
      openingFloat: 2000,
      expectedCash: 2380, // 2000 + 600 - 220
      countedCash: 2375,
      variance: -5,
      salesCount: 5,
      voidedCount: 1,
      notes: 'short by 5',
      closedBy: 'u-1',
      closedByName: 'Cashier One',
      closedAt: DateTime(2026, 5, 28, 21, 30),
    );

    test('round-trips entity -> map -> entity', () {
      final map = DailyClosingModel.fromEntity(entity).toMap();
      final back = DailyClosingModel.fromMap(map, '2026-05-28').toEntity();

      expect(back.id, '2026-05-28');
      expect(back.grossSales, 1000);
      expect(back.cashSales, 600);
      expect(back.nonCashSales, 350);
      expect(back.cashExpenses, 220);
      expect(back.openingFloat, 2000);
      expect(back.expectedCash, 2380);
      expect(back.countedCash, 2375);
      expect(back.variance, -5);
      expect(back.notes, 'short by 5');
      expect(back.closedByName, 'Cashier One');
    });

    test('defaults numeric fields to 0 when missing', () {
      final model = DailyClosingModel.fromMap({}, '2026-01-01');
      expect(model.grossSales, 0);
      expect(model.variance, 0);
      expect(model.salesCount, 0);
      expect(model.notes, isNull);
    });
  });
}
