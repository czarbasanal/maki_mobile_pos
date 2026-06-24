import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/inventory/inventory_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/category_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/cost_code_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';

ProductEntity _p(String id, String name, int qty, int reorder) => ProductEntity(
      id: id,
      sku: id,
      name: name,
      costCode: 'NBF',
      cost: 60.0,
      price: 100.0,
      quantity: qty,
      reorderLevel: reorder,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      category: 'Brakes',
    );

final _admin = UserEntity(
  id: 'u1',
  email: 'a@test',
  displayName: 'Admin',
  role: UserRole.admin,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
);

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final products = [
    _p('in-1', 'In Stock Part', 50, 10), // in stock
    _p('low-1', 'Low Stock Part', 5, 10), // low
    _p('out-1', 'Out Stock Part', 0, 10), // out
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        productsProvider.overrideWith((ref) => Stream.value(products)),
        currentUserProvider.overrideWith((ref) => Stream.value(_admin)),
        activeCategoriesProvider(CategoryKind.product)
            .overrideWith((ref) => Stream.value(const [])),
        costCodeMappingProvider
            .overrideWith((ref) => CostCodeEntity.defaultMapping()),
      ],
      child: const MaterialApp(home: InventoryScreen()),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('summary stats render with counts on AppCard surfaces',
      (tester) async {
    await _pump(tester);

    // Stat labels ('In Stock' also appears as a filter chip, hence findsWidgets).
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('In Stock'), findsWidgets);
    expect(find.text('Low'), findsOneWidget);
    expect(find.text('Out'), findsOneWidget);

    // Counts derived from the seeded products (3 total / 1 in / 1 low / 1 out).
    expect(find.text('3'), findsOneWidget);

    // Both summary cards and product rows are AppCard surfaces now.
    expect(find.byType(AppCard), findsWidgets);
  });

  testWidgets('renders product rows for the seeded catalog', (tester) async {
    await _pump(tester);
    expect(find.text('In Stock Part'), findsOneWidget);
    expect(find.text('Low Stock Part'), findsOneWidget);
  });
}
