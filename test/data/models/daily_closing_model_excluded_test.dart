import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/daily_closing_model.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';

DailyClosingEntity _closing({List<String> ids = const []}) =>
    DailyClosingEntity(
      id: '2026-07-04',
      businessDate: DateTime(2026, 7, 4),
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
      openingFloat: 0,
      expectedCash: 0,
      countedCash: 0,
      variance: 0,
      salesCount: 0,
      voidedCount: 0,
      closedBy: 'u',
      closedByName: 'U',
      closedAt: DateTime(2026, 7, 4),
      excludedExpenseIds: ids,
    );

void main() {
  test('excludedExpenseIds round-trips entity → map → entity', () {
    final model =
        DailyClosingModel.fromEntity(_closing(ids: const ['e1', 'e2']));
    expect(model.toMap()['excludedExpenseIds'], ['e1', 'e2']);
    expect(model.toCreateMap()['excludedExpenseIds'], ['e1', 'e2']);
    expect(model.toEntity().excludedExpenseIds, ['e1', 'e2']);
  });

  test('fromMap tolerates a missing field (legacy closings)', () {
    final model = DailyClosingModel.fromMap({'closedBy': 'u'}, '2026-07-04');
    expect(model.excludedExpenseIds, isEmpty);
  });

  test('fromMap reads the field', () {
    final model = DailyClosingModel.fromMap({
      'excludedExpenseIds': ['a', 'b']
    }, '2026-07-04');
    expect(model.excludedExpenseIds, ['a', 'b']);
  });
}
