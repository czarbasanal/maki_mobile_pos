import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/daily_closing_model.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';

void main() {
  group('DailyClosingModel labor revenue', () {
    DailyClosingEntity entity({double laborRevenue = 0}) => DailyClosingEntity(
          id: '2026-05-28',
          businessDate: DateTime(2026, 5, 28),
          grossSales: 1000,
          netSales: 1000,
          totalDiscounts: 0,
          cashSales: 1450,
          nonCashSales: 0,
          gcashSales: 0,
          mayaSales: 0,
          totalExpenses: 0,
          cashExpenses: 0,
          salmonReceivable: 0,
          laborRevenue: laborRevenue,
          openingFloat: 0,
          expectedCash: 1450,
          countedCash: 1450,
          variance: 0,
          salesCount: 2,
          voidedCount: 0,
          closedBy: 'u1',
          closedByName: 'Admin',
          closedAt: DateTime(2026, 5, 28, 18),
        );

    test('round-trips laborRevenue through toMap/fromMap', () {
      final map = DailyClosingModel.fromEntity(entity(laborRevenue: 450)).toMap();
      expect(map['laborRevenue'], 450);

      final back = DailyClosingModel.fromMap(map, '2026-05-28').toEntity();
      expect(back.laborRevenue, 450);
    });

    test('legacy doc without laborRevenue defaults to 0', () {
      final legacy = DailyClosingModel.fromEntity(entity()).toMap()
        ..remove('laborRevenue');
      final back = DailyClosingModel.fromMap(legacy, '2026-05-28').toEntity();
      expect(back.laborRevenue, 0);
    });
  });
}
