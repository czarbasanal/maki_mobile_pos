import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/daily_closing_model.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';

DailyClosingEntity closing({Map<String, double> feesByType = const {}}) =>
    DailyClosingEntity(
      id: '2026-08-31',
      businessDate: DateTime(2026, 8, 31),
      grossSales: 0,
      netSales: 0,
      totalDiscounts: 0,
      cashSales: 0,
      nonCashSales: 0,
      gcashSales: 0,
      mayaSales: 0,
      totalExpenses: 0,
      cashExpenses: 0,
      salmonReceivable: 0,
      laborRevenue: 0,
      feesRevenue: 0,
      feesByType: feesByType,
      openingFloat: 0,
      expectedCash: 0,
      countedCash: 0,
      variance: 0,
      salesCount: 0,
      voidedCount: 0,
      closedBy: 'u',
      closedByName: 'U',
      closedAt: DateTime(2026, 8, 31, 21),
    );

void main() {
  group('feesByType on the sealed closing', () {
    test('round-trips through the document', () {
      final map = DailyClosingModel.fromEntity(
        closing(feesByType: const {'Electric charge': 250.0, 'Air': 20.0}),
      ).toMap();

      expect(map['feesByType'], {'Electric charge': 250.0, 'Air': 20.0});

      final back = DailyClosingModel.fromMap(map, '2026-08-31').toEntity();
      expect(back.feesByType, {'Electric charge': 250.0, 'Air': 20.0});
    });

    test('a closing sealed before this existed reads as empty, not null', () {
      // Every existing closing is in this state permanently — the document is
      // immutable, so history can never gain a breakdown.
      final legacy = DailyClosingModel.fromEntity(closing()).toMap()
        ..remove('feesByType');

      expect(
        DailyClosingModel.fromMap(legacy, '2026-08-31').toEntity().feesByType,
        isEmpty,
      );
    });

    test('reads ints back as doubles', () {
      // Firestore hands back a whole number as an int.
      final map = DailyClosingModel.fromEntity(closing()).toMap()
        ..['feesByType'] = {'Air': 20};

      expect(
        DailyClosingModel.fromMap(map, '2026-08-31').toEntity().feesByType,
        {'Air': 20.0},
      );
    });
  });
}
