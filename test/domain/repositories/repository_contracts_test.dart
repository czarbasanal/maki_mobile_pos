// test/domain/repositories/repository_contracts_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';

void main() {
  group('Repository Contracts', () {
    test('SaleRepository contract is defined', () {
      // This test just verifies the contract compiles
      // We can't instantiate abstract classes
      expect(SaleRepository, isNotNull);
    });

    test('DraftRepository contract is defined', () {
      expect(DraftRepository, isNotNull);
    });

    test('SalesSummary can be instantiated', () {
      final summary = SalesSummary(
        totalSalesCount: 10,
        voidedSalesCount: 1,
        grossAmount: 10000,
        totalDiscounts: 500,
        netAmount: 9500,
        totalCost: 6000,
        totalProfit: 3500,
        byPaymentMethod: {
          PaymentMethod.cash: 7000,
          PaymentMethod.gcash: 2500,
        },
      );

      expect(summary.totalSalesCount, 10);
      expect(summary.averageSaleAmount, 950);
      expect(summary.profitMargin, closeTo(36.84, 0.01));
    });

    test('SalesSummary.empty creates zero values', () {
      final empty = SalesSummary.empty();

      expect(empty.totalSalesCount, 0);
      expect(empty.netAmount, 0);
      expect(empty.averageSaleAmount, 0);
    });

    test('ProductSalesData can be instantiated', () {
      const data = ProductSalesData(
        productId: 'prod-1',
        sku: 'SKU-001',
        name: 'Test Product',
        quantitySold: 50,
        totalRevenue: 5000,
        totalCost: 3000,
      );

      expect(data.totalProfit, 2000);
      expect(data.profitMargin, 40);
    });
  });
}
