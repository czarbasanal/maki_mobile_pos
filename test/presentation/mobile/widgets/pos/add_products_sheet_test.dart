import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/add_products_sheet.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';

void main() {
  ProductEntity product(String id, {int qty = 5}) => ProductEntity(
        id: id,
        sku: 'SKU-$id',
        name: 'Item $id',
        cost: 55,
        costCode: 'NBF',
        price: 80,
        quantity: qty,
        reorderLevel: 2,
        unit: 'pcs',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );

  Future<void> pumpSheet(WidgetTester tester, AddProductsSheet sheet) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        productsProvider.overrideWith(
            (ref) => Stream.value([product('p1'), product('p2', qty: 0)])),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => sheet,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'doneButton + dedupe: stays open, counts session, chips added rows, Done closes',
      (tester) async {
    final added = <String>[];
    await pumpSheet(
      tester,
      AddProductsSheet(
        title: 'Add products',
        dismiss: AddProductsSheetDismiss.doneButton,
        showSessionCount: true,
        showPrice: false,
        allowOutOfStock: true,
        dedupe: true,
        onProduct: (p) => added.add(p.id),
      ),
    );
    expect(find.text('Add products'), findsOneWidget);
    expect(find.text('0 added this session'), findsOneWidget);

    await search(tester, 'Item');
    // p2 is zero-stock and must be addable with allowOutOfStock.
    await tester.tap(find.text('Item p2'));
    await tester.pumpAndSettle();
    expect(added, ['p2']);
    expect(find.text('1 added this session'), findsOneWidget,
        reason: 'sheet stays open');
    expect(find.text('Added'), findsOneWidget);
    expect(find.textContaining('₱80'), findsNothing,
        reason: 'showPrice: false hides the sale price');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Add products'), findsNothing);
  });

  testWidgets('closeIcon variant: X closes, prices show, no session count',
      (tester) async {
    await pumpSheet(
      tester,
      AddProductsSheet(title: 'Add parts', onProduct: (_) {}),
    );
    expect(find.text('Add parts'), findsOneWidget);
    expect(find.textContaining('added this session'), findsNothing);
    expect(find.text('Done'), findsNothing);

    await search(tester, 'Item p1');
    expect(find.textContaining('₱80'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Add parts'), findsNothing);
  });

  testWidgets('clearQueryOnPick clears the search after a pick',
      (tester) async {
    await pumpSheet(
      tester,
      AddProductsSheet(
          title: 'Add parts', clearQueryOnPick: true, onProduct: (_) {}),
    );
    await search(tester, 'Item p1');
    await tester.tap(find.text('Item p1').last);
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
  });
}
