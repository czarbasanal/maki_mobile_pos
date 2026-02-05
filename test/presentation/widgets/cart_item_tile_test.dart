import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/widgets/pos/cart_item_tile.dart';

void main() {
  const testItem = SaleItemEntity(
    id: 'item-1',
    productId: 'prod-1',
    sku: 'SKU-001',
    name: 'Test Product',
    unitPrice: 100.0,
    unitCost: 60.0,
    quantity: 2,
    discountValue: 10.0,
    unit: 'pcs',
  );

  group('CartItemTile', () {
    testWidgets('displays item information correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CartItemTile(
              item: testItem,
              discountType: DiscountType.amount,
              onQuantityChanged: (_) {},
              onDiscountTap: () {},
              onRemove: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Product'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // quantity
      expect(find.textContaining('SKU-001'), findsOneWidget);
    });

    testWidgets('calls onQuantityChanged when increment pressed',
        (tester) async {
      int? newQuantity;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CartItemTile(
              item: testItem,
              discountType: DiscountType.amount,
              onQuantityChanged: (qty) => newQuantity = qty,
              onDiscountTap: () {},
              onRemove: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(newQuantity, 3);
    });

    testWidgets('calls onRemove when dismissed', (tester) async {
      bool removed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CartItemTile(
              item: testItem,
              discountType: DiscountType.amount,
              onQuantityChanged: (_) {},
              onDiscountTap: () {},
              onRemove: () => removed = true,
            ),
          ),
        ),
      );

      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(removed, true);
    });

    testWidgets('shows discount badge when discount applied', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CartItemTile(
              item: testItem,
              discountType: DiscountType.amount,
              onQuantityChanged: (_) {},
              onDiscountTap: () {},
              onRemove: () {},
            ),
          ),
        ),
      );

      // Should show discount amount
      expect(find.text('₱10'), findsOneWidget);
    });
  });
}
