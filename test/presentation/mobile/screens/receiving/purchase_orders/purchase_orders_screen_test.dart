import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/purchase_order_provider.dart';

void main() {
  PurchaseOrderEntity po(String ref, PurchaseOrderStatus status) =>
      PurchaseOrderEntity(
        id: ref,
        referenceNumber: ref,
        supplierName: 'Acme',
        items: const [],
        totalCost: 0,
        totalQuantity: 3,
        status: status,
        createdAt: DateTime(2026, 7, 3),
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

  testWidgets('lists purchase orders with status pills', (tester) async {
    await pump(tester, [
      po('PO-20260703-001', PurchaseOrderStatus.draft),
      po('PO-20260703-002', PurchaseOrderStatus.ordered),
    ]);
    expect(find.text('PO-20260703-001'), findsOneWidget);
    expect(find.text('PO-20260703-002'), findsOneWidget);
    expect(find.text('Draft'), findsWidgets);
    expect(find.text('Ordered'), findsWidgets);
  });

  testWidgets('status chip filters the list', (tester) async {
    await pump(tester, [
      po('PO-20260703-001', PurchaseOrderStatus.draft),
      po('PO-20260703-002', PurchaseOrderStatus.ordered),
    ]);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ordered'));
    await tester.pumpAndSettle();
    expect(find.text('PO-20260703-001'), findsNothing);
    expect(find.text('PO-20260703-002'), findsOneWidget);
  });

  testWidgets('shows empty state and a new-PO FAB', (tester) async {
    await pump(tester, []);
    expect(find.text('No purchase orders yet'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
