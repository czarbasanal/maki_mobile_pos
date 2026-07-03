import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/purchase_order_provider.dart';

void main() {
  PurchaseOrderEntity po(String ref, PurchaseOrderStatus status,
          {double totalCost = 0}) =>
      PurchaseOrderEntity(
        id: ref,
        referenceNumber: ref,
        supplierName: 'Acme',
        items: const [
          PurchaseOrderItemEntity(
            id: 'p1',
            productId: 'p1',
            sku: 'SKU-1',
            name: 'Brake Pad',
            quantity: 3,
            unit: 'pcs',
            unitCost: 55,
            costCode: 'NBF',
          ),
        ],
        totalCost: totalCost,
        totalQuantity: 3,
        status: status,
        createdAt: DateTime(2026, 7, 3, 9, 41),
        createdBy: 'u1',
        createdByName: 'Admin',
      );

  Future<void> pump(WidgetTester tester, List<PurchaseOrderEntity> pos) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        purchaseOrdersProvider.overrideWith((ref) => Stream.value(pos)),
      ],
      child: const MaterialApp(home: PurchaseOrdersScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('lists purchase orders with supplier, pill, total, friendly date',
      (tester) async {
    await pump(tester, [
      po('PO-20260703-001', PurchaseOrderStatus.draft, totalCost: 5430),
      po('PO-20260703-002', PurchaseOrderStatus.ordered, totalCost: 165),
    ]);
    expect(find.text('PO-20260703-001'), findsOneWidget);
    expect(find.text('PO-20260703-002'), findsOneWidget);
    expect(find.text('Draft'), findsWidgets);
    expect(find.text('Ordered'), findsWidgets);
    // Totals addition: PO grand total on the card, primary-colored.
    expect(find.text('₱5,430.00'), findsOneWidget);
    expect(find.text('₱165.00'), findsOneWidget);
    // Friendly dates + meta line.
    expect(find.text('Jul 3, 9:41 AM'), findsNWidgets(2));
    expect(find.text('1 item · 3 pcs · by Admin'), findsNWidgets(2));
  });

  testWidgets('status pill filters the list', (tester) async {
    await pump(tester, [
      po('PO-20260703-001', PurchaseOrderStatus.draft),
      po('PO-20260703-002', PurchaseOrderStatus.ordered),
    ]);
    await tester.tap(find.byKey(const Key('po-filter-ordered')));
    await tester.pumpAndSettle();
    expect(find.text('PO-20260703-001'), findsNothing);
    expect(find.text('PO-20260703-002'), findsOneWidget);
    await tester.tap(find.byKey(const Key('po-filter-all')));
    await tester.pumpAndSettle();
    expect(find.text('PO-20260703-001'), findsOneWidget);
  });

  testWidgets(
      'empty state is tiled with a New purchase order CTA; create is an app-bar action',
      (tester) async {
    await pump(tester, []);
    expect(find.text('No purchase orders yet'), findsOneWidget);
    expect(
        find.text(
            'Suggestions come from your stock movement. Start one to draft what to buy.'),
        findsOneWidget);
    expect(find.text('New purchase order'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('New purchase order'), findsOneWidget);
    expect(find.byIcon(LucideIcons.plus), findsWidgets);
  });

  testWidgets('error state offers retry', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        purchaseOrdersProvider
            .overrideWith((ref) => Stream.error(Exception('boom'))),
      ],
      child: const MaterialApp(home: PurchaseOrdersScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget,
        reason: 'retry re-subscribes (same failing override) without crashing');
  });
}
