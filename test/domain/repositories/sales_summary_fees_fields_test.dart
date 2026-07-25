import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';

void main() {
  group('SalesSummary fees track', () {
    test('empty() seeds feesRevenue to zero', () {
      final s = SalesSummary.empty();
      expect(s.feesRevenue, 0);
      expect(s.netAmount, 0);
    });

    test('parts-only fields stay independent of the fees track', () {
      const s = SalesSummary(
        totalSalesCount: 2,
        voidedSalesCount: 0,
        grossAmount: 1000,
        totalDiscounts: 100,
        netAmount: 900,
        totalCost: 400,
        totalProfit: 500,
        byPaymentMethod: {PaymentMethod.cash: 1050},
        feesRevenue: 150,
      );
      // Parts-only top-line untouched by shop fees.
      expect(s.netAmount, 900);
      expect(s.totalProfit, 500);
      expect(s.totalCost, 400);
      // Fees are their own track.
      expect(s.feesRevenue, 150);
      // Cash bucket is fees-inclusive: net(parts) + fees == Σ byPaymentMethod.
      final tenderTotal =
          s.byPaymentMethod.values.fold<double>(0, (a, b) => a + b);
      expect(tenderTotal, s.netAmount + s.feesRevenue);
    });

    test('profitMargin still divides parts profit by parts net', () {
      const s = SalesSummary(
        totalSalesCount: 1,
        voidedSalesCount: 0,
        grossAmount: 1000,
        totalDiscounts: 0,
        netAmount: 1000,
        totalCost: 600,
        totalProfit: 400,
        byPaymentMethod: {},
        feesRevenue: 999,
      );
      expect(s.profitMargin, 40); // fees must not skew the parts margin
    });
  });
}
