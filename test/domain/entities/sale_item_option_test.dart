import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

ProductEntity product() => ProductEntity(
      id: 'p1',
      sku: 'ABC-1',
      name: 'Pulley Ball',
      costCode: 'NBF',
      cost: 60,
      price: 120,
      quantity: 12,
      reorderLevel: 3,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 7, 29),
    );

void main() {
  const by3 = SellingOptionEntity(id: 'o2', label: 'By 3', pieces: 3, price: 330);

  group('SaleItemEntity option snapshot', () {
    test('quantity stays in pieces and unitPrice is per piece', () {
      final item = SaleItemModel.fromProductOption(
        itemId: 'i1',
        product: product(),
        option: by3,
      ).toEntity();
      expect(item.quantity, 3);
      expect(item.unitPrice, 110);
      expect(item.grossAmount, 330);
    });

    test('two sets means six pieces', () {
      final item = SaleItemModel.fromProductOption(
        itemId: 'i1',
        product: product(),
        option: by3,
        sets: 2,
      ).toEntity();
      expect(item.quantity, 6);
      expect(item.optionSets, 2);
      expect(item.grossAmount, 660);
    });

    test('a non-terminating per-piece price still totals the set price', () {
      const odd = SellingOptionEntity(id: 'o3', label: 'By 3', pieces: 3, price: 100);
      final item = SaleItemModel.fromProductOption(
        itemId: 'i1',
        product: product(),
        option: odd,
      ).toEntity();
      expect(item.grossAmount, closeTo(100, 0.0001));
    });

    test('unit cost is per piece so line cost is pieces x cost', () {
      final item = SaleItemModel.fromProductOption(
        itemId: 'i1',
        product: product(),
        option: by3,
      ).toEntity();
      expect(item.unitCost, 60);
      expect(item.totalCost, 180);
    });

    test('a line with no option has null option fields and steps by 1', () {
      final item = SaleItemModel.fromProduct(
        itemId: 'i1',
        product: product(),
      ).toEntity();
      expect(item.hasOption, isFalse);
      expect(item.optionSets, isNull);
      expect(item.quantityStep, 1);
    });

    test('a line with an option steps by its piece count', () {
      final item = SaleItemModel.fromProductOption(
        itemId: 'i1',
        product: product(),
        option: by3,
      ).toEntity();
      expect(item.hasOption, isTrue);
      expect(item.quantityStep, 3);
    });

    test('round-trips option fields through toMap/fromMap', () {
      final model = SaleItemModel.fromProductOption(
        itemId: 'i1',
        product: product(),
        option: by3,
      );
      final parsed = SaleItemModel.fromMap(model.toMap(), 'i1');
      expect(parsed.optionId, 'o2');
      expect(parsed.optionLabel, 'By 3');
      expect(parsed.optionPieces, 3);
      expect(parsed.optionPrice, 330);
    });

    test('a legacy map with no option fields parses to nulls', () {
      final parsed = SaleItemModel.fromMap({
        'productId': 'p1',
        'sku': 'ABC-1',
        'name': 'Pulley Ball',
        'unitPrice': 120.0,
        'unitCost': 60.0,
        'quantity': 2,
      }, 'i1');
      expect(parsed.optionId, isNull);
      expect(parsed.toEntity().hasOption, isFalse);
    });
  });
}
