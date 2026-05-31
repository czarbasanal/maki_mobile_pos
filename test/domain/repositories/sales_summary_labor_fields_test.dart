import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';

void main() {
  group('SalesSummary labor track', () {
    test('empty() seeds labor fields to zero', () {
      final s = SalesSummary.empty();
      expect(s.laborRevenue, 0);
      expect(s.laborProfit, 0);
      expect(s.netAmount, 0);
    });

    test('parts-only fields stay independent of the labor track', () {
      const s = SalesSummary(
        totalSalesCount: 2,
        voidedSalesCount: 0,
        grossAmount: 1000,
        totalDiscounts: 100,
        netAmount: 900,
        totalCost: 400,
        totalProfit: 500,
        byPaymentMethod: {PaymentMethod.cash: 1350},
        laborRevenue: 450,
        laborProfit: 450,
      );
      // Parts-only top-line untouched by labor.
      expect(s.netAmount, 900);
      expect(s.totalProfit, 500);
      expect(s.totalCost, 400);
      // Labor is its own track (zero cost ⇒ profit == revenue).
      expect(s.laborRevenue, 450);
      expect(s.laborProfit, 450);
      // Cash bucket is labor-inclusive: net(parts) + labor == Σ byPaymentMethod.
      final tenderTotal =
          s.byPaymentMethod.values.fold<double>(0, (a, b) => a + b);
      expect(tenderTotal, s.netAmount + s.laborRevenue);
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
        laborRevenue: 999,
        laborProfit: 999,
      );
      expect(s.profitMargin, 40); // labor must not skew the parts margin
    });
  });
}
