import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

ProductModel model({List<SellingOptionEntity> options = const []}) {
  return ProductModel(
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
    sellingOptions: options,
  );
}

void main() {
  group('ProductModel selling options', () {
    const by6 = SellingOptionEntity(id: 'o1', label: 'By 6', pieces: 6, price: 600);
    const by3 = SellingOptionEntity(id: 'o2', label: 'By 3', pieces: 3, price: 330);

    test('a doc with no sellingOptions field parses to an empty list', () {
      final parsed = ProductModel.fromMap({
        'sku': 'ABC-1',
        'name': 'Pulley Ball',
        'costCode': 'NBF',
        'cost': 60,
        'price': 120,
        'quantity': 12,
        'reorderLevel': 3,
        'unit': 'pcs',
        'isActive': true,
      }, 'p1');
      expect(parsed.sellingOptions, isEmpty);
      expect(parsed.toEntity().hasSellingOptions, isFalse);
    });

    test('round-trips options through toMap/fromMap', () {
      final map = model(options: [by6, by3]).toMap();
      final parsed = ProductModel.fromMap(map, 'p1');
      expect(parsed.sellingOptions, [by6, by3]);
      expect(parsed.toEntity().hasSellingOptions, isTrue);
    });

    test('toUpdateMap omits sellingOptions by default', () {
      final map = model(options: [by6]).toUpdateMap('u1');
      expect(map.containsKey('sellingOptions'), isFalse);
    });

    test('toUpdateMap includes sellingOptions when asked', () {
      final map = model(options: [by6])
          .toUpdateMap('u1', includeSellingOptions: true);
      expect(map['sellingOptions'], hasLength(1));
    });

    test('entity round-trips through fromEntity/toEntity', () {
      final entity = model(options: [by6, by3]).toEntity();
      expect(ProductModel.fromEntity(entity).sellingOptions, [by6, by3]);
    });
  });
}
