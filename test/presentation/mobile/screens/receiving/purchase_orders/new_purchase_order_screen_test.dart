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

  Future<FakeFirebaseFirestore> pump(
    WidgetTester tester, {
    required List<ReorderSuggestion> suggestions,
    List<ProductEntity> lowStock = const [],
    List<ProductEntity> outOfStock = const [],
  }) async {
    final fake = FakeFirebaseFirestore();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(fake),
        productsProvider.overrideWith(
            (ref) => Stream.value([product('p1'), product('p2')])),
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        reorderSuggestionsProvider.overrideWith((ref, params) async =>
            ReorderResult(
                suggestions: suggestions,
                lowStock: lowStock,
                outOfStock: outOfStock,
                capped: false)),
      ],
      child: const MaterialApp(home: NewPurchaseOrderScreen()),
    ));
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('default view groups by status', (tester) async {
    // The redesigned layout (params card + view toggle + card rows) is taller
    // than the default 800×600 test surface; give the lazy list room so the
    // third section actually builds.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      suggestions: [suggestion(product('p1'), 9)],
      outOfStock: [product('p2', supplier: null)],
      lowStock: [
        ProductEntity(
          id: 'p3',
          sku: 'SKU-p3',
          name: 'Item p3',
          cost: 55,
          costCode: 'NBF',
          price: 80,
          quantity: 1,
          reorderLevel: 5,
          unit: 'pcs',
          isActive: true,
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Out of stock'), findsOneWidget);
    expect(find.text('Low stock'), findsOneWidget);
    expect(find.text('Item p1'), findsOneWidget);
    expect(find.text('Item p2'), findsOneWidget);
    expect(find.text('Item p3'), findsOneWidget);
    // Low-stock row prefills a top-up to the reorder level: 5 − 1 = 4.
    expect(find.text('4'), findsOneWidget);
    // No supplier headers in status view.
    expect(find.text('Acme'), findsNothing);
  });

  testWidgets('supplier toggle shows supplier groups', (tester) async {
    await pump(tester, suggestions: [
      suggestion(product('p1'), 9),
      suggestion(product('p2', supplier: null), 4),
    ]);
    await tester.tap(find.byKey(const Key('po-view-bySupplier')));
    await tester.pumpAndSettle();
    expect(find.text('Item p1'), findsOneWidget);
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('No supplier'), findsOneWidget);
  });

  testWidgets('low/out rows are unchecked by default and excluded from save',
      (tester) async {
    final fake = await pump(
      tester,
      suggestions: [suggestion(product('p1'), 9)],
      outOfStock: [product('p2', supplier: null)],
    );

    await tester.tap(find.byKey(const Key('po-create-button')));
    await tester.pumpAndSettle();

    final orders = await fake.collection('purchase_orders').get();
    expect(orders.size, 1,
        reason: 'zero-velocity items must not silently pad orders');
    final items = orders.docs.single.data()['items'] as List;
    expect((items.single as Map)['productId'], 'p1');
  });

  testWidgets('save creates one draft PO per supplier', (tester) async {
    final fake = await pump(tester, suggestions: [
      suggestion(product('p1'), 9),
      suggestion(product('p2', supplier: null), 4),
    ]);

    await tester.tap(find.byKey(const Key('po-create-button')));
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

    // Add p2 via the add-products sheet (search → result row → Done).
    await tester.tap(find.byTooltip('Add product'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Item p2');
    await tester.pump(const Duration(milliseconds: 350)); // search debounce
    await tester.pumpAndSettle();
    // .last — the typed query in the field also matches; the result row is
    // the second match.
    await tester.tap(find.text('Item p2').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Bump its qty 1 → 3 (the p2 row is the last plus-button).
    await tester.tap(find.byIcon(LucideIcons.plus).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.plus).last);
    await tester.pumpAndSettle();

    // Change the movement window — previously this rebuilt lines and reset
    // the manual row.
    await tester.tap(find.byKey(const Key('po-window-30')));
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
    await tester.tap(find.byKey(const Key('po-check-p2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('po-create-button')));
    await tester.pumpAndSettle();

    final orders = await fake.collection('purchase_orders').get();
    expect(orders.size, 1);
  });

  testWidgets('sheet stays open, accumulates adds, and chips added rows',
      (tester) async {
    await pump(tester, suggestions: [suggestion(product('p1'), 9)]);

    await tester.tap(find.byTooltip('Add product'));
    await tester.pumpAndSettle();
    expect(find.text('Add products'), findsOneWidget);
    expect(find.text('0 added this session'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Item');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Both overridden products are results; p2 is zero-stock (quantity: 0)
    // and must still be addable on a purchase order.
    await tester.tap(find.text('Item p2'));
    await tester.pumpAndSettle();
    expect(find.text('1 added this session'), findsOneWidget,
        reason: 'sheet stays open after a pick');
    // Scoped to the sheet — the builder behind it also gains an "Added"
    // section header for the same product.
    expect(
        find.descendant(
            of: find.byType(BottomSheet), matching: find.text('Added')),
        findsOneWidget,
        reason: 'the picked row now shows the Added chip');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Item p2'), findsWidgets,
        reason: 'p2 landed in the builder lines');
  });

  testWidgets('sheet result rows hide the sale price', (tester) async {
    await pump(tester, suggestions: [suggestion(product('p1'), 9)]);
    await tester.tap(find.byTooltip('Add product'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Item p2');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.textContaining('₱80'), findsNothing,
        reason: 'the PO sheet is cost/price-free like the CSV');
  });

  testWidgets('create button carries the live supplier-group count',
      (tester) async {
    await pump(tester, suggestions: [
      suggestion(product('p1'), 9),
      suggestion(product('p2', supplier: null), 4),
    ]);
    expect(find.text('Create 2 purchase orders'), findsOneWidget);
    await tester.tap(find.byKey(const Key('po-check-p2')));
    await tester.pumpAndSettle();
    expect(find.text('Create 1 purchase order'), findsOneWidget);
  });

  testWidgets('footer shows running total of checked lines only',
      (tester) async {
    // p1: 9 × ₱55 = ₱495; p2: 4 × ₱55 = ₱220 → both: ₱715.00
    await pump(tester, suggestions: [
      suggestion(product('p1'), 9),
      suggestion(product('p2', supplier: null), 4),
    ]);
    expect(find.textContaining('₱715.00'), findsOneWidget);
    expect(find.text('One PO per supplier'), findsOneWidget);
    await tester.tap(find.byKey(const Key('po-check-p2')));
    await tester.pumpAndSettle();
    expect(find.textContaining('₱495.00'), findsOneWidget);
  });

  testWidgets('supplier view headers show checked subtotal', (tester) async {
    await pump(tester, suggestions: [suggestion(product('p1'), 9)]);
    await tester.tap(find.byKey(const Key('po-view-bySupplier')));
    await tester.pumpAndSettle();
    expect(find.text('1 item · ₱495.00'), findsOneWidget);
  });

  testWidgets(
      'supplier view splits two suppliers sharing a display name (grouped by id, like save)',
      (tester) async {
    ProductEntity sameName(String id, String supplierId) => ProductEntity(
          id: id,
          sku: 'SKU-$id',
          name: 'Item $id',
          cost: 55,
          costCode: 'NBF',
          price: 80,
          quantity: 0,
          reorderLevel: 2,
          unit: 'pcs',
          supplierId: supplierId,
          supplierName: 'Acme',
          isActive: true,
          createdAt: DateTime(2026, 1, 1),
        );
    await pump(tester, suggestions: [
      suggestion(sameName('p1', 'sup-A'), 9),
      suggestion(sameName('p2', 'sup-B'), 4),
    ]);
    await tester.tap(find.byKey(const Key('po-view-bySupplier')));
    await tester.pumpAndSettle();
    // Two sections (one per supplierId) — matching the 2 POs save creates.
    expect(find.text('Acme'), findsNWidgets(2));
    expect(find.text('Create 2 purchase orders'), findsOneWidget);
    expect(find.text('1 item · ₱495.00'), findsOneWidget);
    expect(find.text('1 item · ₱220.00'), findsOneWidget);
  });

  testWidgets('cover stepper applies after the debounce', (tester) async {
    final received = <({int coverDays, int windowDays})>[];
    final fake = FakeFirebaseFirestore();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(fake),
        productsProvider.overrideWith((ref) => Stream.value([product('p1')])),
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        reorderSuggestionsProvider.overrideWith((ref, params) async {
          received.add(params);
          return ReorderResult(
              suggestions: [suggestion(product('p1'), 9)],
              lowStock: const [],
              outOfStock: const [],
              capped: false);
        }),
      ],
      child: const MaterialApp(home: NewPurchaseOrderScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('po-cover-plus')));
    await tester.pump();
    expect(find.text('31'), findsOneWidget,
        reason: 'display updates instantly');
    expect(received.map((p) => p.coverDays), isNot(contains(31)),
        reason: 'refetch waits for the debounce');

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(received.map((p) => p.coverDays), contains(31));
  });

  testWidgets('cap note renders the amber warning copy', (tester) async {
    final fake = FakeFirebaseFirestore();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(fake),
        productsProvider.overrideWith((ref) => Stream.value([product('p1')])),
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        reorderSuggestionsProvider.overrideWith((ref, params) async =>
            ReorderResult(
                suggestions: [suggestion(product('p1'), 9)],
                lowStock: const [],
                outOfStock: const [],
                capped: true)),
      ],
      child: const MaterialApp(home: NewPurchaseOrderScreen()),
    ));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Movement data may be incomplete — the sales cap was reached for this window.'),
        findsOneWidget);
  });
}
