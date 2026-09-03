import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/product_tag_sheet.dart';
import 'package:maki_mobile_pos/presentation/providers/tag_provider.dart';

class _FakeProductTagOps extends ProductTagOperationsNotifier {
  _FakeProductTagOps(super.ref);
  final writes = <List<String>>[];

  @override
  Future<bool> setTags({
    required String productId,
    required List<String> tagIds,
  }) async {
    writes.add(List.of(tagIds));
    return true;
  }
}

TagEntity _tag(String id, String name) => TagEntity(
      id: id,
      name: name,
      color: 'green',
      isActive: true,
      createdAt: DateTime(2026, 9, 1),
    );

void main() {
  testWidgets('toggling tags writes the composed list each tap', (tester) async {
    _FakeProductTagOps? ops;
    final product = ProductEntity(
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
      tagIds: const ['t2'],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        activeTagsProvider.overrideWith(
          (ref) => Stream.value([_tag('t1', 'Intact'), _tag('t2', 'Recheck')]),
        ),
        productTagOperationsProvider.overrideWith((ref) {
          ops = _FakeProductTagOps(ref);
          return ops!;
        }),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showProductTagSheet(context, product: product),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Intact'));
    await tester.pump();
    expect(ops!.writes.last, ['t2', 't1']);

    await tester.tap(find.text('Recheck'));
    await tester.pump();
    expect(ops!.writes.last, ['t1']);
  });
}
