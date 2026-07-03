import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/utils/reorder_suggestions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/purchase_order_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

void main() {
  ProductEntity product(String id, {String? supplier = 'Acme'}) =>
      ProductEntity(
        id: id,
        sku: 'SKU-$id',
        name: 'Item $id',
        cost: 55,
        costCode: 'NBF',
        price: 80,
        quantity: 0,
        reorderLevel: 2,
        unit: 'pcs',
        supplierId: supplier == null ? null : 'sup-$supplier',
        supplierName: supplier,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );

  final user = UserEntity(
    id: 'u1',
    email: 'u@x.com',
    displayName: 'Admin',
    role: UserRole.admin,
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  );

  ReorderSuggestion suggestion(ProductEntity p, int qty) => ReorderSuggestion(
        product: p,
        velocityPerDay: 1,
        targetStock: qty,
        suggestedQty: qty,
      );

  Future<FakeFirebaseFirestore> pump(WidgetTester tester,
      {required List<ReorderSuggestion> suggestions}) async {
    final fake = FakeFirebaseFirestore();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(fake),
        productsProvider.overrideWith(
            (ref) => Stream.value([product('p1'), product('p2')])),
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        reorderSuggestionsProvider.overrideWith((ref, params) async =>
            ReorderResult(suggestions: suggestions, capped: false)),
      ],
      child: const MaterialApp(home: NewPurchaseOrderScreen()),
    ));
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('renders suggestion rows grouped by supplier', (tester) async {
    await pump(tester, suggestions: [
      suggestion(product('p1'), 9),
      suggestion(product('p2', supplier: null), 4),
    ]);
    expect(find.text('Item p1'), findsOneWidget);
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('No supplier'), findsOneWidget);
  });

  testWidgets('save creates one draft PO per supplier', (tester) async {
    final fake = await pump(tester, suggestions: [
      suggestion(product('p1'), 9),
      suggestion(product('p2', supplier: null), 4),
    ]);

    await tester.tap(find.text('Save drafts'));
    await tester.pumpAndSettle();

    final orders = await fake.collection('purchase_orders').get();
    expect(orders.size, 2);
    final statuses = orders.docs.map((d) => d.data()['status']).toSet();
    expect(statuses, {'draft'});
    final suppliers = orders.docs.map((d) => d.data()['supplierName']).toSet();
    expect(suppliers, {'Acme', null});
  });

  testWidgets('manually added product keeps its qty when params change',
      (tester) async {
    // p1 is suggested; p2 is added manually. The overridden provider returns
    // the same suggestions for every params value, so switching the window
    // chip only forces the rebuild path that previously dropped manual state.
    await pump(tester, suggestions: [suggestion(product('p1'), 9)]);

    // Add p2 via the search sheet.
    await tester.tap(find.byTooltip('Add product'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Item p2'));
    await tester.pumpAndSettle();

    // Bump its qty 1 → 3 (the p2 row is the last plus-button).
    await tester.tap(find.byIcon(LucideIcons.plus).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.plus).last);
    await tester.pumpAndSettle();

    // Change the movement window — previously this rebuilt lines and reset
    // the manual row.
    await tester.tap(find.widgetWithText(ChoiceChip, '30d'));
    await tester.pumpAndSettle();

    expect(find.text('Item p2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget,
        reason: 'the manually set quantity must survive a params change');
  });

  testWidgets('unchecking a row excludes it from the save', (tester) async {
    final fake = await pump(tester, suggestions: [
      suggestion(product('p1'), 9),
      suggestion(product('p2', supplier: null), 4),
    ]);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save drafts'));
    await tester.pumpAndSettle();

    final orders = await fake.collection('purchase_orders').get();
    expect(orders.size, 1);
  });
}
