import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('DraftEntity', () {
    late DraftEntity draft;

    setUp(() {
      draft = DraftEntity(
        id: 'draft-1',
        name: 'Table 5',
        items: const [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Product 1',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: 2,
          ),
        ],
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime.now(),
      );
    });

    test('addItem adds new item', () {
      const newItem = SaleItemEntity(
        id: 'item-2',
        productId: 'prod-2',
        sku: 'SKU-002',
        name: 'Product 2',
        unitPrice: 50.0,
        unitCost: 30.0,
        quantity: 1,
      );

      final updated = draft.addItem(newItem);
      expect(updated.items.length, 2);
    });

    test('addItem updates quantity for existing product', () {
      const sameProduct = SaleItemEntity(
        id: 'item-new',
        productId: 'prod-1', // Same product
        sku: 'SKU-001',
        name: 'Product 1',
        unitPrice: 100.0,
        unitCost: 60.0,
        quantity: 3,
      );

      final updated = draft.addItem(sameProduct);
      expect(updated.items.length, 1); // Still 1 item
      expect(updated.items.first.quantity, 5); // 2 + 3
    });

    test('removeItem removes item', () {
      final updated = draft.removeItem('item-1');
      expect(updated.items.isEmpty, true);
    });

    test('updateItemQuantity updates correctly', () {
      final updated = draft.updateItemQuantity('item-1', 5);
      expect(updated.items.first.quantity, 5);
    });

    test('updateItemQuantity removes item when quantity is 0', () {
      final updated = draft.updateItemQuantity('item-1', 0);
      expect(updated.items.isEmpty, true);
    });

    test('applyItemDiscount applies discount', () {
      final updated = draft.applyItemDiscount('item-1', 15.0);
      expect(updated.items.first.discountValue, 15.0);
    });

    test('changeDiscountType resets all discounts', () {
      // First apply a discount
      var updated = draft.applyItemDiscount('item-1', 10.0);
      expect(updated.items.first.discountValue, 10.0);

      // Change type
      updated = updated.changeDiscountType(DiscountType.percentage);
      expect(updated.discountType, DiscountType.percentage);
      expect(updated.items.first.discountValue, 0.0); // Reset
    });

    test('canCheckout returns correctly', () {
      expect(draft.canCheckout, true);

      final empty = draft.clearItems();
      expect(empty.canCheckout, false);

      final converted = draft.markAsConverted('sale-1');
      expect(converted.canCheckout, false);
    });

    test('markAsConverted sets conversion info', () {
      final converted = draft.markAsConverted('sale-1');
      expect(converted.isConverted, true);
      expect(converted.convertedToSaleId, 'sale-1');
      expect(converted.convertedAt, isNotNull);
    });
  });
}
