import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/cart_item_tile.dart';

SaleItemEntity item({String? label, int? pieces, double? optionPrice, int quantity = 1}) {
  return SaleItemEntity(
    id: 'i1',
    productId: 'p1',
    sku: 'ABC-1',
    name: 'Pulley Ball',
    unitPrice: pieces == null ? 120 : (optionPrice ?? 0) / pieces,
    unitCost: 60,
    quantity: quantity,
    unit: 'pcs',
    optionId: label == null ? null : 'o2',
    optionLabel: label,
    optionPieces: pieces,
    optionPrice: optionPrice,
  );
}

Future<List<int>> pumpTile(WidgetTester tester, SaleItemEntity value) async {
  final emitted = <int>[];
  // CartItemTile embeds CostCodePill, a ConsumerWidget — needs a ProviderScope
  // ancestor (not in the brief's literal snippet) or the pump throws
  // StateError('No ProviderScope found') before any assertion runs.
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: CartItemTile(
          item: value,
          discountType: DiscountType.amount,
          onQuantityChanged: emitted.add,
          onDiscountTap: () {},
          onRemove: () {},
        ),
      ),
    ),
  ));
  return emitted;
}

void main() {
  group('CartItemTile with a selling option', () {
    testWidgets('shows the option label beside the name', (tester) async {
      await pumpTile(tester, item(label: 'By 3', pieces: 3, optionPrice: 330, quantity: 3));
      expect(find.textContaining('By 3'), findsWidgets);
    });

    testWidgets('shows sets and total pieces for more than one set', (tester) async {
      await pumpTile(tester, item(label: 'By 3', pieces: 3, optionPrice: 330, quantity: 6));
      expect(find.textContaining('By 3 × 2'), findsOneWidget);
      expect(find.textContaining('6 pcs'), findsOneWidget);
    });

    testWidgets('does not show a set count for a single set', (tester) async {
      await pumpTile(tester, item(label: 'By 3', pieces: 3, optionPrice: 330, quantity: 3));
      expect(find.textContaining('× 2'), findsNothing);
    });

    testWidgets('a line with no option renders unchanged', (tester) async {
      await pumpTile(tester, item(quantity: 2));
      expect(find.textContaining('By'), findsNothing);
    });
  });

  group('CartItemTile quantity stepping', () {
    testWidgets('plus steps a By 3 line by three pieces', (tester) async {
      final emitted =
          await pumpTile(tester, item(label: 'By 3', pieces: 3, optionPrice: 330, quantity: 3));
      await tester.tap(find.byIcon(LucideIcons.plus));
      await tester.pump();
      expect(emitted, [6]);
    });

    testWidgets('minus steps a By 3 line down by three pieces', (tester) async {
      final emitted =
          await pumpTile(tester, item(label: 'By 3', pieces: 3, optionPrice: 330, quantity: 6));
      await tester.tap(find.byIcon(LucideIcons.minus));
      await tester.pump();
      expect(emitted, [3]);
    });

    testWidgets('minus is disabled at one whole set', (tester) async {
      await pumpTile(tester, item(label: 'By 3', pieces: 3, optionPrice: 330, quantity: 3));
      final minus = tester.widget<IconButton>(
        find.ancestor(of: find.byIcon(LucideIcons.minus), matching: find.byType(IconButton)),
      );
      expect(minus.onPressed, isNull);
    });

    testWidgets('the control displays sets, not pieces', (tester) async {
      await pumpTile(tester, item(label: 'By 3', pieces: 3, optionPrice: 330, quantity: 6));
      expect(find.text('2'), findsOneWidget);
      expect(find.text('6'), findsNothing);
    });

    testWidgets('a plain line still steps by one', (tester) async {
      final emitted = await pumpTile(tester, item(quantity: 2));
      await tester.tap(find.byIcon(LucideIcons.plus));
      await tester.pump();
      expect(emitted, [3]);
    });
  });
}
