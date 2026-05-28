import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/batch_import.dart';
import 'package:maki_mobile_pos/core/utils/inventory_export.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';

ProductEntity _product({
  required String sku,
  required String name,
  String? category,
  String unit = 'pcs',
  double cost = 10,
  double price = 15,
  int quantity = 5,
  int reorderLevel = 2,
}) =>
    ProductEntity(
      id: 'id-$sku',
      sku: sku,
      name: name,
      costCode: '',
      cost: cost,
      price: price,
      quantity: quantity,
      reorderLevel: reorderLevel,
      unit: unit,
      category: category,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('buildInventoryCsv', () {
    test('first row is the batch-import header', () {
      final csv = buildInventoryCsv([_product(sku: 'A', name: 'Apple')]);
      final firstLine = csv.split('\n').first.trim();
      expect(firstLine, kBatchImportColumns.join(','));
    });

    test('writes one row per product with formatted cells', () {
      final csv = buildInventoryCsv([
        _product(
          sku: 'A',
          name: 'Apple',
          category: 'Fruit',
          unit: 'kg',
          cost: 12.5,
          price: 20,
          quantity: 7,
          reorderLevel: 3,
        ),
      ]);
      final lines = csv.trim().split('\n');
      expect(lines.length, 2);
      expect(lines[1].trim(), 'A,Apple,Fruit,kg,12.50,20.00,7,3');
    });

    test('null category serializes as an empty cell', () {
      final csv = buildInventoryCsv([_product(sku: 'B', name: 'Bare')]);
      // sku,name,,unit,... -> two commas after name
      expect(csv, contains('B,Bare,,pcs,'));
    });

    test('round-trips cleanly back through parseBatchImportCsv', () {
      final products = [
        _product(sku: 'A', name: 'Apple', category: 'Fruit', cost: 12.5,
            price: 20, quantity: 7, reorderLevel: 3),
        _product(sku: 'B', name: 'Banana', cost: 5, price: 8,
            quantity: 2, reorderLevel: 1),
      ];

      final parsed = parseBatchImportCsv(buildInventoryCsv(products));

      expect(parsed.errors, isEmpty);
      expect(parsed.rows.length, 2);
      expect(parsed.rows[0].sku, 'A');
      expect(parsed.rows[0].name, 'Apple');
      expect(parsed.rows[0].cost, 12.5);
      expect(parsed.rows[0].price, 20);
      expect(parsed.rows[0].quantity, 7);
      expect(parsed.rows[0].reorderLevel, 3);
      expect(parsed.rows[1].sku, 'B');
      expect(parsed.rows[1].quantity, 2);
    });
  });
}
