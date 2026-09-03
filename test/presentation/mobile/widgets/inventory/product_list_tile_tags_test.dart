import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/product_list_tile.dart';

ProductEntity _product() => ProductEntity(
      id: 'p1',
      sku: 'SKU-1',
      name: 'Brake shoe',
      costCode: 'NBF',
      cost: 100,
      price: 150,
      quantity: 5,
      reorderLevel: 1,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

TagEntity _tag(String id, String name) => TagEntity(
      id: id,
      name: name,
      color: 'green',
      isActive: true,
      createdAt: DateTime(2026, 9, 1),
    );

Widget _harness(List<TagEntity> tags) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ProductListTile(
            product: _product(),
            showCost: false,
            onTap: () {},
            tags: tags,
          ),
        ),
      ),
    );

void main() {
  testWidgets('renders no chips when the product has no tags', (tester) async {
    await tester.pumpWidget(_harness(const []));
    expect(find.text('Intact'), findsNothing);
  });

  testWidgets('renders up to two chips plus a +n overflow', (tester) async {
    await tester.pumpWidget(_harness([
      _tag('t1', 'Intact'),
      _tag('t2', 'Recheck'),
      _tag('t3', 'Promo'),
    ]));
    expect(find.text('Intact'), findsOneWidget);
    expect(find.text('Recheck'), findsOneWidget);
    expect(find.text('Promo'), findsNothing);
    expect(find.text('+1'), findsOneWidget);
  });
}
