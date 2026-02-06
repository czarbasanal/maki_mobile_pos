import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/widgets/inventory/product_list_tile.dart';

void main() {
  final testProduct = ProductEntity(
    id: 'prod-1',
    sku: 'SKU-001',
    name: 'Test Product',
    costCode: 'NBF',
    cost: 60.0,
    price: 100.0,
    quantity: 50,
    reorderLevel: 10,
    unit: 'pcs',
    isActive: true,
    createdAt: DateTime.now(),
    category: 'Electronics',
  );

  group('ProductListTile', () {
    testWidgets('displays product information', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductListTile(
              product: testProduct,
              showCost: false,
              onTap: () {},
              onStockAdjust: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Product'), findsOneWidget);
      expect(find.text('SKU-001'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
    });

    testWidgets('shows cost code when showCost is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductListTile(
              product: testProduct,
              showCost: false,
              onTap: () {},
              onStockAdjust: () {},
            ),
          ),
        ),
      );

      expect(find.text('NBF'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('shows actual cost when showCost is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductListTile(
              product: testProduct,
              showCost: true,
              onTap: () {},
              onStockAdjust: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('60.00'), findsOneWidget);
    });

    testWidgets('shows low stock warning', (tester) async {
      final lowStockProduct = testProduct.copyWith(quantity: 5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductListTile(
              product: lowStockProduct,
              showCost: false,
              onTap: () {},
              onStockAdjust: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.warning), findsOneWidget);
    });
  });
}
