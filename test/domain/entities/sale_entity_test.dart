import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('SaleEntity', () {
    late SaleEntity sale;
    late List<SaleItemEntity> items;

    setUp(() {
      items = [
        const SaleItemEntity(
          id: 'item-1',
          productId: 'prod-1',
          sku: 'SKU-001',
          name: 'Product 1',
          unitPrice: 100.0,
          unitCost: 60.0,
          quantity: 2,
          discountValue: 10.0, // 10 peso off OR 10% off
        ),
        const SaleItemEntity(
          id: 'item-2',
          productId: 'prod-2',
          sku: 'SKU-002',
          name: 'Product 2',
          unitPrice: 50.0,
          unitCost: 30.0,
          quantity: 3,
          discountValue: 5.0, // 5 peso off OR 5% off
        ),
      ];

      sale = SaleEntity(
        id: 'sale-1',
        saleNumber: 'SALE-20250205-001',
        items: items,
        discountType: DiscountType.amount,
        paymentMethod: PaymentMethod.cash,
        amountReceived: 350.0,
        changeGiven: 15.0,
        cashierId: 'cashier-1',
        cashierName: 'John Doe',
        createdAt: DateTime.now(),
      );
    });

    test('subtotal calculates correctly', () {
      // Item 1: 100 * 2 = 200
      // Item 2: 50 * 3 = 150
      // Total: 350
      expect(sale.subtotal, 350.0);
    });

    test('totalDiscount with amount type', () {
      // Item 1: 10 peso discount
      // Item 2: 5 peso discount
      // Total: 15
      expect(sale.totalDiscount, 15.0);
    });

    test('grandTotal with amount discount', () {
      // 350 - 15 = 335
      expect(sale.grandTotal, 335.0);
    });

    test('totalDiscount with percentage type', () {
      final percentageSale =
          sale.copyWith(discountType: DiscountType.percentage);
      // Item 1: 200 * 0.10 = 20
      // Item 2: 150 * 0.05 = 7.5
      // Total: 27.5
      expect(percentageSale.totalDiscount, 27.5);
    });

    test('grandTotal with percentage discount', () {
      final percentageSale =
          sale.copyWith(discountType: DiscountType.percentage);
      // 350 - 27.5 = 322.5
      expect(percentageSale.grandTotal, 322.5);
    });

    test('totalCost calculates correctly', () {
      // Item 1: 60 * 2 = 120
      // Item 2: 30 * 3 = 90
      // Total: 210
      expect(sale.totalCost, 210.0);
    });

    test('totalProfit calculates correctly', () {
      // grandTotal - totalCost = 335 - 210 = 125
      expect(sale.totalProfit, 125.0);
    });

    test('totalItemCount calculates correctly', () {
      // 2 + 3 = 5
      expect(sale.totalItemCount, 5);
    });

    test('uniqueProductCount calculates correctly', () {
      expect(sale.uniqueProductCount, 2);
    });

    test('void_ creates voided sale', () {
      final voidedSale = sale.void_(
        voidedById: 'admin-1',
        voidedByUserName: 'Admin User',
        reason: 'Customer returned',
      );

      expect(voidedSale.isVoided, true);
      expect(voidedSale.voidedBy, 'admin-1');
      expect(voidedSale.voidedByName, 'Admin User');
      expect(voidedSale.voidReason, 'Customer returned');
      expect(voidedSale.voidedAt, isNotNull);
    });

    test('isFromDraft returns correctly', () {
      expect(sale.isFromDraft, false);

      final fromDraft = sale.copyWith(draftId: 'draft-1');
      expect(fromDraft.isFromDraft, true);
    });
  });
}
