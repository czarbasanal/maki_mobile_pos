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

  group('DraftEntity labor + money math', () {
    late DraftEntity draft;

    setUp(() {
      draft = DraftEntity(
        id: 'draft-1',
        name: 'Bike repair',
        items: const [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Brake pad',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: 2,
            discountValue: 10.0, // 10 peso off (amount type)
          ),
        ],
        discountType: DiscountType.amount,
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime.now(),
      );
    });

    test('laborLines defaults to empty and mechanic fields default to null', () {
      expect(draft.laborLines, isEmpty);
      expect(draft.mechanicId, isNull);
      expect(draft.mechanicName, isNull);
    });

    test('parts getters with no labor', () {
      // subtotal: 100 * 2 = 200; discount: 10
      expect(draft.partsSubtotal, 200.0);
      expect(draft.laborSubtotal, 0.0);
      expect(draft.partsRevenue, 190.0); // 200 - 10
      expect(draft.laborRevenue, 0.0);
      expect(draft.grandTotal, 190.0); // partsRevenue + laborRevenue
      // cost: 60 * 2 = 120
      expect(draft.totalCost, 120.0);
      expect(draft.partsProfit, 70.0); // 190 - 120
      expect(draft.laborProfit, 0.0);
      expect(draft.totalProfit, 70.0);
    });

    test('addLaborLine adds a labor line and feeds laborSubtotal', () {
      final updated = draft.addLaborLine(
        const LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 300.0),
      );
      expect(updated.laborLines.length, 1);
      expect(updated.laborSubtotal, 300.0);
      // Original is unchanged (immutability).
      expect(draft.laborLines, isEmpty);
    });

    test('labor lines raise revenue/profit/grandTotal but not parts/discount/cost',
        () {
      final updated = draft
          .addLaborLine(
            const LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 300.0),
          )
          .addLaborLine(
            const LaborLineEntity(id: 'lab-2', description: 'Bleed', fee: 150.0),
          );

      // Labor does NOT touch parts-only figures.
      expect(updated.partsSubtotal, 200.0);
      expect(updated.totalDiscount, 10.0);
      expect(updated.totalCost, 120.0);
      expect(updated.partsRevenue, 190.0);
      expect(updated.partsProfit, 70.0);

      // Labor track.
      expect(updated.laborSubtotal, 450.0);
      expect(updated.laborRevenue, 450.0);
      expect(updated.laborProfit, 450.0); // zero labor cost

      // Combined.
      expect(updated.grandTotal, 640.0); // 190 + 450
      expect(updated.totalProfit, 520.0); // 70 + 450
    });

    test('updateLaborLine replaces a matching line by id', () {
      final updated = draft
          .addLaborLine(
            const LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 300.0),
          )
          .updateLaborLine(
            const LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 500.0),
          );
      expect(updated.laborLines.single.fee, 500.0);
      expect(updated.laborSubtotal, 500.0);
    });

    test('updateLaborLine on a missing id is a no-op', () {
      final updated = draft
          .addLaborLine(
            const LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 300.0),
          )
          .updateLaborLine(
            const LaborLineEntity(id: 'nope', description: 'X', fee: 999.0),
          );
      expect(updated.laborLines.single.fee, 300.0);
    });

    test('removeLaborLine drops the matching line', () {
      final updated = draft
          .addLaborLine(
            const LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 300.0),
          )
          .addLaborLine(
            const LaborLineEntity(id: 'lab-2', description: 'Bleed', fee: 150.0),
          )
          .removeLaborLine('lab-1');
      expect(updated.laborLines.single.id, 'lab-2');
      expect(updated.laborSubtotal, 150.0);
    });

    test('copyWith sets and clears mechanic fields', () {
      final assigned =
          draft.copyWith(mechanicId: 'mech-1', mechanicName: 'Juan Dela Cruz');
      expect(assigned.mechanicId, 'mech-1');
      expect(assigned.mechanicName, 'Juan Dela Cruz');

      final cleared = assigned.copyWith(clearMechanic: true);
      expect(cleared.mechanicId, isNull);
      expect(cleared.mechanicName, isNull);
    });

    test('props include laborLines and mechanic fields', () {
      final a = draft.copyWith(mechanicId: 'mech-1', mechanicName: 'Juan');
      final b = draft.copyWith(mechanicId: 'mech-2', mechanicName: 'Pedro');
      expect(a == b, false);

      final withLabor = draft.addLaborLine(
        const LaborLineEntity(id: 'lab-1', description: 'Tune-up', fee: 300.0),
      );
      expect(withLabor == draft, false);
    });
  });

  group('DraftEntity motorcycleModel', () {
    test('copyWith + props carry motorcycleModel', () {
      final d = DraftEntity(
        id: 'd1',
        name: 'ABC-123',
        items: const [],
        createdBy: 'u1',
        createdByName: 'C',
        createdAt: DateTime(2026, 7, 1),
      );
      expect(d.motorcycleModel, isNull);
      final withModel = d.copyWith(motorcycleModel: 'Click 125i');
      expect(withModel.motorcycleModel, 'Click 125i');
      expect(withModel, isNot(equals(d)));
    });
  });
}
