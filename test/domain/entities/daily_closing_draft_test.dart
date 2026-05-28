import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';

ExpenseEntity _exp(double amount, PaymentMethod paidVia) => ExpenseEntity(
      id: 'e',
      description: 'x',
      amount: amount,
      category: 'c',
      date: DateTime(2026, 5, 28),
      paidVia: paidVia,
      createdAt: DateTime(2026, 5, 28),
      createdBy: '',
      createdByName: '',
    );

void main() {
  group('DailyClosingDraft.fromData', () {
    test('splits cash vs non-cash sales and cash expenses', () {
      const summary = SalesSummary(
        totalSalesCount: 5,
        voidedSalesCount: 1,
        grossAmount: 1000,
        totalDiscounts: 50,
        netAmount: 950,
        totalCost: 400,
        totalProfit: 550,
        byPaymentMethod: {
          PaymentMethod.cash: 600,
          PaymentMethod.gcash: 250,
          PaymentMethod.maya: 100,
        },
      );

      final draft = DailyClosingDraft.fromData(
        businessDate: DateTime(2026, 5, 28),
        summary: summary,
        expenses: [
          _exp(200, PaymentMethod.cash),
          _exp(80, PaymentMethod.gcash),
          _exp(20, PaymentMethod.cash),
        ],
      );

      expect(draft.grossSales, 1000);
      expect(draft.netSales, 950);
      expect(draft.cashSales, 600);
      expect(draft.nonCashSales, 350); // 250 + 100
      expect(draft.totalExpenses, 300); // 200 + 80 + 20
      expect(draft.cashExpenses, 220); // 200 + 20
      expect(draft.salesCount, 5);
      expect(draft.voidedCount, 1);
    });

    test('handles a day with no cash sales and no expenses', () {
      const summary = SalesSummary(
        totalSalesCount: 0,
        voidedSalesCount: 0,
        grossAmount: 0,
        totalDiscounts: 0,
        netAmount: 0,
        totalCost: 0,
        totalProfit: 0,
        byPaymentMethod: {},
      );

      final draft = DailyClosingDraft.fromData(
        businessDate: DateTime(2026, 5, 28),
        summary: summary,
        expenses: const [],
      );

      expect(draft.cashSales, 0);
      expect(draft.nonCashSales, 0);
      expect(draft.cashExpenses, 0);
      expect(draft.totalExpenses, 0);
    });

    test('salmon balance is a receivable, excluded from cash and non-cash', () {
      const summary = SalesSummary(
        totalSalesCount: 2,
        voidedSalesCount: 0,
        grossAmount: 2000,
        totalDiscounts: 0,
        netAmount: 2000,
        totalCost: 0,
        totalProfit: 2000,
        byPaymentMethod: {
          PaymentMethod.cash: 900, // 400 dp + 500 mixed cash
          PaymentMethod.gcash: 500,
          PaymentMethod.salmon: 600,
        },
      );

      final draft = DailyClosingDraft.fromData(
        businessDate: DateTime(2026, 5, 28),
        summary: summary,
        expenses: const [],
      );

      expect(draft.cashSales, 900);
      expect(draft.nonCashSales, 500); // gcash only; salmon excluded
      expect(draft.salmonReceivable, 600);
      // Opening float 1000 + cash 900 - 0 expenses = 1900; salmon untouched.
      expect(draft.expectedCashFor(1000), 1900);
    });

    test('expectedCash applies the opening float', () {
      const summary = SalesSummary(
        totalSalesCount: 1,
        voidedSalesCount: 0,
        grossAmount: 600,
        totalDiscounts: 0,
        netAmount: 600,
        totalCost: 0,
        totalProfit: 600,
        byPaymentMethod: {PaymentMethod.cash: 600},
      );
      final draft = DailyClosingDraft.fromData(
        businessDate: DateTime(2026, 5, 28),
        summary: summary,
        expenses: [_exp(100, PaymentMethod.cash)],
      );

      // 2000 float + 600 cash sales - 100 cash expenses = 2500
      expect(draft.expectedCashFor(2000), 2500);
    });
  });
}
