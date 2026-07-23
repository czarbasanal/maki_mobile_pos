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
      gcashSales: 350,
      mayaSales: 0,
      totalExpenses: 300,
      cashExpenses: 220,
      salmonReceivable: 600,
      plateNoDp: 300,
      plateNoDelivery: 50,
      plateNoDpAmounts: const [100, 200],
      plateNoDeliveryAmounts: const [50],
      openingFloat: 2000,
      expectedCash: 2630, // 2000 + 600 - 220 + 300 - 50
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
      expect(back.expectedCash, 2630);
      expect(back.countedCash, 2375);
      expect(back.variance, -5);
      expect(back.plateNoDp, 300);
      expect(back.plateNoDelivery, 50);
      expect(back.plateNoDpAmounts, [100, 200]);
      expect(back.plateNoDeliveryAmounts, [50]);
      expect(back.notes, 'short by 5');
      expect(back.closedByName, 'Cashier One');
    });

    test('defaults numeric fields to 0 when missing', () {
      final model = DailyClosingModel.fromMap({}, '2026-01-01');
      expect(model.grossSales, 0);
      expect(model.variance, 0);
      expect(model.salesCount, 0);
      expect(model.plateNoDp, 0);
      expect(model.plateNoDelivery, 0);
      expect(model.plateNoDpAmounts, isEmpty);
      expect(model.plateNoDeliveryAmounts, isEmpty);
      expect(model.notes, isNull);
    });
  });
}
