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

    test('breaks non-cash into gcash + maya buckets', () {
      const summary = SalesSummary(
        totalSalesCount: 3,
        voidedSalesCount: 0,
        grossAmount: 5000,
        totalDiscounts: 0,
        netAmount: 5000,
        totalCost: 0,
        totalProfit: 5000,
        byPaymentMethod: {
          PaymentMethod.cash: 1000,
          PaymentMethod.gcash: 3000,
          PaymentMethod.maya: 1000,
        },
      );

      final draft = DailyClosingDraft.fromData(
        businessDate: DateTime(2026, 5, 28),
        summary: summary,
        expenses: const [],
      );

      expect(draft.gcashSales, 3000);
      expect(draft.mayaSales, 1000);
      expect(draft.nonCashSales, 4000);
      // Invariant.
      expect(draft.gcashSales + draft.mayaSales, draft.nonCashSales);
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

    test('plate-no DP adds to and delivery subtracts from expected cash', () {
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

      // 2000 float + 600 cash - 100 cash exp + 300 dp - 50 delivery = 2750
      expect(
        draft.expectedCashFor(2000, plateNoDp: 300, plateNoDelivery: 50),
        2750,
      );
      // Defaults leave the base reconciliation unchanged.
      expect(draft.expectedCashFor(2000), 2500);
    });

    test('carries labor revenue as its own line; cash stays labor-inclusive',
        () {
      const summary = SalesSummary(
        totalSalesCount: 2,
        voidedSalesCount: 0,
        grossAmount: 1000, // parts gross (parts-only)
        totalDiscounts: 0,
        netAmount: 1000, // parts net (parts-only)
        totalCost: 600,
        totalProfit: 400,
        byPaymentMethod: {PaymentMethod.cash: 1450}, // parts 1000 + labor 450
        laborRevenue: 450,
        laborProfit: 450,
      );

      final draft = DailyClosingDraft.fromData(
        businessDate: DateTime(2026, 5, 28),
        summary: summary,
        expenses: const [],
      );

      // Parts-only top-line on the closing snapshot.
      expect(draft.grossSales, 1000);
      expect(draft.netSales, 1000);
      // Labor surfaced as its own line.
      expect(draft.laborRevenue, 450);
      // Expected cash is labor-inclusive: 0 float + 1450 cash - 0 expenses.
      expect(draft.expectedCashFor(0), 1450);
    });

    test(
        'carries fees revenue as its own line; expectedCash unchanged by it',
        () {
      const summaryNoFees = SalesSummary(
        totalSalesCount: 2,
        voidedSalesCount: 0,
        grossAmount: 1000, // parts gross (parts-only)
        totalDiscounts: 0,
        netAmount: 1000, // parts net (parts-only)
        totalCost: 600,
        totalProfit: 400,
        byPaymentMethod: {PaymentMethod.cash: 1000}, // parts only
      );
      const summaryWithFees = SalesSummary(
        totalSalesCount: 2,
        voidedSalesCount: 0,
        grossAmount: 1000, // parts gross (parts-only)
        totalDiscounts: 0,
        netAmount: 1000, // parts net (parts-only)
        totalCost: 600,
        totalProfit: 400,
        byPaymentMethod: {PaymentMethod.cash: 1150}, // parts 1000 + fees 150
        feesRevenue: 150,
      );

      final draftNoFees = DailyClosingDraft.fromData(
        businessDate: DateTime(2026, 5, 28),
        summary: summaryNoFees,
        expenses: const [],
      );
      final draftWithFees = DailyClosingDraft.fromData(
        businessDate: DateTime(2026, 5, 28),
        summary: summaryWithFees,
        expenses: const [],
      );

      // Parts-only top-line on the closing snapshot.
      expect(draftWithFees.grossSales, 1000);
      expect(draftWithFees.netSales, 1000);
      // Fees surfaced as their own line.
      expect(draftWithFees.feesRevenue, 150);
      expect(draftNoFees.feesRevenue, 0);
      // Fee cash is already inside cashSales (drawer physically holds it):
      // expectedCash is fees-inclusive via cashSales, same as labor.
      expect(draftWithFees.expectedCashFor(0), 1150);

      // CRITICAL invariant: expectedCashFor's *formula* is unchanged by the
      // feesRevenue field — two drafts with identical cashSales/cashExpenses
      // but different feesRevenue produce the identical expectedCash.
      final draftA = DailyClosingDraft(
        businessDate: DateTime(2026, 5, 28),
        grossSales: 0,
        netSales: 0,
        totalDiscounts: 0,
        cashSales: 1000,
        nonCashSales: 0,
        gcashSales: 0,
        mayaSales: 0,
        totalExpenses: 0,
        cashExpenses: 0,
        salmonReceivable: 0,
        feesRevenue: 0,
        salesCount: 0,
        voidedCount: 0,
      );
      final draftB = DailyClosingDraft(
        businessDate: DateTime(2026, 5, 28),
        grossSales: 0,
        netSales: 0,
        totalDiscounts: 0,
        cashSales: 1000,
        nonCashSales: 0,
        gcashSales: 0,
        mayaSales: 0,
        totalExpenses: 0,
        cashExpenses: 0,
        salmonReceivable: 0,
        feesRevenue: 999, // wildly different fees, same cash inputs
        salesCount: 0,
        voidedCount: 0,
      );
      expect(draftA.expectedCashFor(500), draftB.expectedCashFor(500));
      expect(draftA.expectedCashFor(500), 1500);
    });
  });
}
