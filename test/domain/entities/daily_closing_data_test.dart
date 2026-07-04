import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';

ExpenseEntity _exp(String id, double amount, PaymentMethod paidVia) =>
    ExpenseEntity(
      id: id,
      description: 'x-$id',
      amount: amount,
      category: 'c',
      date: DateTime(2026, 7, 4),
      paidVia: paidVia,
      createdAt: DateTime(2026, 7, 4),
      createdBy: '',
      createdByName: '',
    );

void main() {
  const summary = SalesSummary(
    totalSalesCount: 2,
    voidedSalesCount: 0,
    grossAmount: 1000,
    totalDiscounts: 0,
    netAmount: 1000,
    totalCost: 0,
    totalProfit: 1000,
    byPaymentMethod: {PaymentMethod.cash: 700, PaymentMethod.gcash: 300},
  );

  final data = DailyClosingData(
    businessDate: DateTime(2026, 7, 4),
    summary: summary,
    expenses: [
      _exp('e1', 150, PaymentMethod.cash),
      _exp('e2', 50, PaymentMethod.gcash),
      _exp('e3', 200, PaymentMethod.cash),
    ],
  );

  group('DailyClosingData.draftExcluding', () {
    test('empty exclusions = full-list math', () {
      final draft = data.draftExcluding(const {});
      expect(draft.totalExpenses, 400);
      expect(draft.cashExpenses, 350);
      // float 1000 + cash 700 - cashExp 350
      expect(draft.expectedCashFor(1000), 1350);
    });

    test('excluding a cash expense removes it from totals AND drawer math',
        () {
      final draft = data.draftExcluding(const {'e3'});
      expect(draft.totalExpenses, 200); // 150 + 50
      expect(draft.cashExpenses, 150);
      expect(draft.expectedCashFor(1000), 1550); // 1000 + 700 - 150
    });

    test('excluding a non-cash expense changes totals but not drawer math',
        () {
      final draft = data.draftExcluding(const {'e2'});
      expect(draft.totalExpenses, 350);
      expect(draft.cashExpenses, 350);
      expect(draft.expectedCashFor(1000), 1350);
    });

    test('unknown ids are ignored', () {
      expect(data.draftExcluding(const {'nope'}).totalExpenses, 400);
    });
  });

  test('excludedExpenseIds participates in DailyClosingEntity equality', () {
    DailyClosingEntity closing(List<String> ids) => DailyClosingEntity(
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
          closedBy: '',
          closedByName: '',
          closedAt: DateTime(2026, 7, 4),
          excludedExpenseIds: ids,
        );
    expect(closing(const ['a']) == closing(const ['b']), isFalse);
    expect(closing(const []).excludedExpenseIds, isEmpty);
  });
}
