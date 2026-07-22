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

ProductEntity _p(String id, String name, {required double cost, required double price, required int qty}) =>
    ProductEntity(
      id: id,
      sku: id,
      name: name,
      costCode: 'NBF',
      cost: cost,
      price: price,
      quantity: qty,
      reorderLevel: 5,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      category: 'Brakes',
    );

// Two products: (cost 20 x qty 10 = 200, price 40 x qty 10 = 400) and
// (cost 25 x qty 20 = 500, price 45 x qty 20 = 900).
// Totals: cost 700, retail 1300, profit 600.
final _products = [
  _p('p1', 'Brake Pad', cost: 20, price: 40, qty: 10),
  _p('p2', 'Brake Disc', cost: 25, price: 45, qty: 20),
];

final _admin = UserEntity(
  id: 'u1',
  email: 'admin@test',
  displayName: 'Admin',
  role: UserRole.admin,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
);

final _staff = UserEntity(
  id: 'u2',
  email: 'staff@test',
  displayName: 'Staff',
  role: UserRole.staff,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
);

Future<void> _pump(WidgetTester tester, UserEntity user) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        productsProvider.overrideWith((ref) => Stream.value(_products)),
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
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
  testWidgets('admin sees the inventory totals strip with correct figures',
      (tester) async {
    await _pump(tester, _admin);

    expect(find.text('Stock Cost'), findsOneWidget);
    expect(find.text('₱700.00'), findsOneWidget);
    expect(find.text('Retail Value'), findsOneWidget);
    expect(find.text('₱1,300.00'), findsOneWidget);
    expect(find.text('Expected Profit'), findsOneWidget);
    expect(find.text('₱600.00'), findsOneWidget);
  });

  testWidgets('staff does not see the inventory totals strip', (tester) async {
    await _pump(tester, _staff);

    expect(find.text('Stock Cost'), findsNothing);
    expect(find.text('Retail Value'), findsNothing);
    expect(find.text('Expected Profit'), findsNothing);
  });
}
