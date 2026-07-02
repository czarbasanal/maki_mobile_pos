import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/product_search_field.dart';

void main() {
  ProductEntity product({int quantity = 14}) => ProductEntity(
        id: 'p-1',
        sku: 'OIL-M3000',
        name: 'Motul 3000 4T 1L',
        costCode: 'X',
        cost: 200,
        price: 320,
        quantity: quantity,
        reorderLevel: 2,
        unit: 'pcs',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );

  Future<List<ProductEntity>> pump(
    WidgetTester tester, {
    int quantity = 14,
  }) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    final selected = <ProductEntity>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productsProvider
              .overrideWith((ref) => Stream.value([product(quantity: quantity)])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 500,
              child: ProductSearchField(
                controller: controller,
                focusNode: focusNode,
                inlineResults: true,
                onProductSelected: selected.add,
                onBarcodeScanned: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return selected;
  }

  Future<void> search(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'motul');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  testWidgets('inline mode renders result rows with stock count in-flow',
      (tester) async {
    await pump(tester);
    await search(tester);
    expect(find.text('Motul 3000 4T 1L'), findsOneWidget);
    expect(find.textContaining('14 in stock'), findsOneWidget);
  });

  testWidgets('the + button adds the product', (tester) async {
    final selected = await pump(tester);
    await search(tester);
    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pump();
    expect(selected, hasLength(1));
    expect(selected.single.sku, 'OIL-M3000');
  });

  testWidgets('tapping the row also adds the product', (tester) async {
    final selected = await pump(tester);
    await search(tester);
    await tester.tap(find.text('Motul 3000 4T 1L'));
    await tester.pump();
    expect(selected, hasLength(1));
  });

  testWidgets('out-of-stock rows hide the + button and cannot be added',
      (tester) async {
    final selected = await pump(tester, quantity: 0);
    await search(tester);
    expect(find.textContaining('0 in stock'), findsOneWidget);
    expect(find.byIcon(LucideIcons.plus), findsNothing);
    await tester.tap(find.text('Motul 3000 4T 1L'), warnIfMissed: false);
    await tester.pump();
    expect(selected, isEmpty);
  });
}
