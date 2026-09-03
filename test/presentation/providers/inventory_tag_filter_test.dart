import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/inventory_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/tag_provider.dart';

ProductEntity _product(String id, {List<String> tagIds = const []}) =>
    ProductEntity(
      id: id,
      sku: 'SKU-$id',
      name: 'Product $id',
      costCode: 'NBF',
      cost: 100,
      price: 150,
      quantity: 5,
      reorderLevel: 1,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      tagIds: tagIds,
    );

TagEntity _tag(String id) => TagEntity(
      id: id,
      name: 'Tag $id',
      color: 'green',
      isActive: true,
      createdAt: DateTime(2026, 9, 1),
    );

void main() {
  final products = [
    _product('a', tagIds: ['t1']),
    _product('b', tagIds: ['t2']),
    _product('c'),
    _product('d', tagIds: ['deleted-tag']),
  ];

  ProviderContainer makeContainer() {
    final container = ProviderContainer(overrides: [
      productsProvider.overrideWith((ref) => Stream.value(products)),
      activeTagsProvider.overrideWith(
        (ref) => Stream.value([_tag('t1'), _tag('t2')]),
      ),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Future<List<String>> idsAfter(
    ProviderContainer container,
    String? tagFilter,
  ) async {
    await container.read(productsProvider.future);
    await container.read(activeTagsProvider.future);
    container.read(inventoryStateProvider.notifier).setTagFilter(tagFilter);
    final result = container.read(filteredProductsProvider);
    return result.value!.map((p) => p.id).toList();
  }

  test('no tag filter returns everything', () async {
    expect(await idsAfter(makeContainer(), null), ['a', 'b', 'c', 'd']);
  });

  test('a specific tag id matches only its products', () async {
    expect(await idsAfter(makeContainer(), 't1'), ['a']);
  });

  test('untagged = no ACTIVE tag; orphaned ids count as untagged', () async {
    expect(await idsAfter(makeContainer(), kUntaggedFilter), ['c', 'd']);
  });
}
