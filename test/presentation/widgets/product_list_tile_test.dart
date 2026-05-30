import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/product_list_tile.dart';
import 'package:maki_mobile_pos/presentation/providers/cost_code_provider.dart';

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
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ProductListTile(
                product: testProduct,
                showCost: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test Product'), findsOneWidget);
      expect(find.text('SKU-001'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
    });

    testWidgets('shows cost code when showCost is false', (tester) async {
      // CostCodePill encodes the live cost via the active mapping (it does
      // not echo the stored costCode string), so seed the mapping to get a
      // deterministic code instead of the loading placeholder.
      final mapping = CostCodeEntity.defaultMapping();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            costCodeMappingProvider.overrideWith((ref) => mapping),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProductListTile(
                product: testProduct,
                showCost: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(CupertinoIcons.lock), findsOneWidget);
      // cost 60 -> "ZS" under the default mapping (6->Z, 0->S).
      expect(find.text(mapping.encode(testProduct.cost)), findsOneWidget);
    });

    testWidgets('shows actual cost when showCost is true', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ProductListTile(
                product: testProduct,
                showCost: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('60.00'), findsOneWidget);
    });

    testWidgets('shows low stock warning', (tester) async {
      final lowStockProduct = testProduct.copyWith(quantity: 5);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ProductListTile(
                product: lowStockProduct,
                showCost: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      // Low-stock products show the triangle indicator (per _stockStyle).
      expect(
        find.byIcon(CupertinoIcons.exclamationmark_triangle),
        findsOneWidget,
      );
    });
  });
}
