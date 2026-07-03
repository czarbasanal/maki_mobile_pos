import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/reorder_suggestions.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';

void main() {
  ProductEntity product({
    String id = 'p1',
    int quantity = 0,
    bool isActive = true,
    String? supplierName = 'Acme',
  }) =>
      ProductEntity(
        id: id,
        sku: 'SKU-$id',
        name: 'Item $id',
        cost: 100,
        costCode: 'AB',
        price: 150,
        quantity: quantity,
        reorderLevel: 2,
        unit: 'pcs',
        supplierId: supplierName == null ? null : 'sup-1',
        supplierName: supplierName,
        isActive: isActive,
        createdAt: DateTime(2026, 1, 1),
      );

  const params = (windowDays: 30, coverDays: 14);

  test('suggests velocity × cover − stock', () {
    // 30 units / 30 days = 1/day × 14 cover = target 14, stock 5 → suggest 9.
    final out = computeReorderSuggestions(
        [product(quantity: 5)], {'p1': 30}, params);
    expect(out, hasLength(1));
    expect(out.first.velocityPerDay, 1);
    expect(out.first.targetStock, 14);
    expect(out.first.suggestedQty, 9);
  });

  test('rounds the target up (ceil)', () {
    // 10 / 30 = 0.333/day × 14 = 4.66 → ceil 5; stock 0 → 5.
    final out = computeReorderSuggestions([product()], {'p1': 10}, params);
    expect(out.first.targetStock, 5);
    expect(out.first.suggestedQty, 5);
  });

  test('excludes zero-velocity and already-stocked products', () {
    final out = computeReorderSuggestions(
      [product(id: 'dead'), product(id: 'full', quantity: 999)],
      {'full': 30},
      params,
    );
    expect(out, isEmpty);
  });

  test('skips inactive products; sorts supplier asc then qty desc', () {
    final out = computeReorderSuggestions(
      [
        product(id: 'p1', supplierName: 'Beta'),
        product(id: 'p2', supplierName: 'Acme'),
        product(id: 'gone', isActive: false),
      ],
      {'p1': 30, 'p2': 60, 'gone': 60},
      params,
    );
    expect(out.map((s) => s.product.id).toList(), ['p2', 'p1']);
    expect(out.first.supplierName, 'Acme');
  });

  test('null supplier sorts last', () {
    final out = computeReorderSuggestions(
      [
        product(id: 'nosup', supplierName: null),
        product(id: 'acme', supplierName: 'Acme'),
      ],
      {'nosup': 30, 'acme': 30},
      params,
    );
    expect(out.map((s) => s.product.id).toList(), ['acme', 'nosup']);
    expect(out.last.supplierName, isNull);
  });
}
