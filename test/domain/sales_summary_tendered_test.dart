import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';

SalesSummary summary({
  double net = 8840,
  Map<PaymentMethod, double> tenders = const {},
  double labor = 950,
}) =>
    SalesSummary(
      totalSalesCount: 21,
      voidedSalesCount: 0,
      grossAmount: net,
      totalDiscounts: 0,
      netAmount: net,
      totalCost: 0,
      totalProfit: net,
      byPaymentMethod: tenders,
      laborRevenue: labor,
      laborProfit: labor,
    );

void main() {
  group('SalesSummary.totalTendered', () {
    test('sums the tender buckets, which include labor and fee cash', () {
      // 2026-08-30: ₱8,840 of parts and ₱950 of labor. The tenders hold both;
      // netAmount holds only the parts. Dividing tenders by netAmount is what
      // made the report and the dashboard disagree.
      final s = summary(tenders: const {
        PaymentMethod.cash: 8500,
        PaymentMethod.gcash: 1290,
      });

      expect(s.totalTendered, 9790);
      expect(s.netAmount, 8840);
      // Against the right denominator the shares close at 100%.
      final pct = s.byPaymentMethod.values
          .map((v) => v / s.totalTendered * 100)
          .fold(0.0, (a, b) => a + b);
      expect(pct, closeTo(100, 0.001));
    });

    test('is zero when nothing was tendered, so a share never divides by it', () {
      expect(summary(tenders: const {}).totalTendered, 0);
    });
  });
}
