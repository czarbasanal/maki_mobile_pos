import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('SaleItemEntity', () {
    late SaleItemEntity item;

    setUp(() {
      item = const SaleItemEntity(
        id: 'item-1',
        productId: 'prod-1',
        sku: 'TEST-001',
        name: 'Test Product',
        unitPrice: 100.0,
        unitCost: 60.0,
        quantity: 3,
        discountValue: 10.0,
        unit: 'pcs',
      );
    });

    test('grossAmount calculates correctly', () {
      expect(item.grossAmount, 300.0); // 100 * 3
    });

    test('totalCost calculates correctly', () {
      expect(item.totalCost, 180.0); // 60 * 3
    });

    test('amount discount calculates correctly', () {
      // discountValue = 10 (peso amount)
      expect(item.calculateDiscountAmount(isPercentage: false), 10.0);
      expect(item.calculateNetAmount(isPercentage: false), 290.0);
      expect(item.calculateProfit(isPercentage: false), 110.0); // 290 - 180
    });

    test('percentage discount calculates correctly', () {
      // discountValue = 10 (10% off)
      expect(
          item.calculateDiscountAmount(isPercentage: true), 30.0); // 300 * 0.1
      expect(item.calculateNetAmount(isPercentage: true), 270.0);
      expect(item.calculateProfit(isPercentage: true), 90.0); // 270 - 180
    });

    test('amount discount caps at gross amount', () {
      final largeDiscount = item.copyWith(discountValue: 500.0);
      expect(
        largeDiscount.calculateDiscountAmount(isPercentage: false),
        300.0, // Capped at gross amount
      );
    });

    test('hasDiscount returns correctly', () {
      expect(item.hasDiscount, true);

      final noDiscount = item.copyWith(discountValue: 0);
      expect(noDiscount.hasDiscount, false);
    });
  });
}
