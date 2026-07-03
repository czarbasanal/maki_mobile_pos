import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/purchase_order_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

void main() {
  late FakeFirebaseFirestore fake;
  late PurchaseOrderRepositoryImpl repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = PurchaseOrderRepositoryImpl(firestore: fake);
  });

  UserEntity user(UserRole role) => UserEntity(
        id: 'u1',
        email: 'u@x.com',
        displayName: 'U',
        role: role,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );

  Future<PurchaseOrderEntity> seed(
      {PurchaseOrderStatus status = PurchaseOrderStatus.draft}) async {
    final po = await repo.createPurchaseOrder(PurchaseOrderEntity(
      id: '',
      referenceNumber: 'PO-20260703-001',
      supplierName: 'Acme',
      items: const [
        PurchaseOrderItemEntity(
          id: 'p1',
          productId: 'p1',
          sku: 'SKU-1',
          name: 'Brake Pad',
          quantity: 4,
          unit: 'pcs',
          unitCost: 55,
          costCode: 'NBF',
        ),
      ],
      totalCost: 220,
      totalQuantity: 4,
      status: PurchaseOrderStatus.draft,
      createdAt: DateTime(2026, 7, 3),
      createdBy: 'u1',
      createdByName: 'Admin',
    ));
    if (status == PurchaseOrderStatus.ordered) {
      await repo.markOrdered(po.id);
    }
    return (await repo.getPurchaseOrderById(po.id))!;
  }

  Future<void> pump(WidgetTester tester, String id, UserRole role) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(fake),
        currentUserProvider.overrideWith((ref) => Stream.value(user(role))),
      ],
      child: MaterialApp(home: PurchaseOrderDetailScreen(purchaseOrderId: id)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('draft shows items and Mark ordered', (tester) async {
    final po = await seed();
    await pump(tester, po.id, UserRole.staff);
    expect(find.text('PO-20260703-001'), findsNWidgets(2));
    expect(find.text('Brake Pad'), findsOneWidget);
    expect(find.text('Mark ordered'), findsOneWidget);
    expect(find.text('Receive delivery'), findsNothing);
  });

  testWidgets('Mark ordered transitions to ordered with Receive',
      (tester) async {
    final po = await seed();
    await pump(tester, po.id, UserRole.staff);
    await tester.tap(find.text('Mark ordered'));
    await tester.pumpAndSettle();
    expect(find.text('Receive delivery'), findsOneWidget);
    expect(find.text('Back to draft'), findsOneWidget);
  });

  testWidgets('Receive creates a linked draft receiving', (tester) async {
    final po = await seed(status: PurchaseOrderStatus.ordered);
    await pump(tester, po.id, UserRole.staff);
    await tester.tap(find.text('Receive delivery'));
    await tester.pumpAndSettle();

    final receivings = await fake.collection('receivings').get();
    expect(receivings.size, 1);
    expect(receivings.docs.first.data()['purchaseOrderId'], po.id);
  });

  testWidgets('qty edits are buffered locally and flushed by Save changes',
      (tester) async {
    final po = await seed();
    await pump(tester, po.id, UserRole.staff);

    // Two + taps: no write yet.
    await tester.tap(find.byIcon(LucideIcons.plus).first);
    await tester.pump();
    await tester.tap(find.byIcon(LucideIcons.plus).first);
    await tester.pumpAndSettle();
    var doc =
        await fake.collection('purchase_orders').doc(po.id).get();
    expect(
        (doc.data()!['items'] as List).first['quantity'], 4,
        reason: 'stepper taps must not write until Save changes');
    expect(find.text('6x'), findsOneWidget);

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    doc = await fake.collection('purchase_orders').doc(po.id).get();
    expect((doc.data()!['items'] as List).first['quantity'], 6);
    expect((doc.data()!['totalQuantity'] as num).toInt(), 6);
    expect(find.text('Save changes'), findsNothing,
        reason: 'buffer clears after a successful save');
  });

  testWidgets('Delete is admin-only', (tester) async {
    final po = await seed();
    await pump(tester, po.id, UserRole.staff);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('shows per-item subtotal line and footer grand total',
      (tester) async {
    final po = await seed(); // 4 × ₱55 = ₱220
    await pump(tester, po.id, UserRole.staff);
    expect(find.text('₱55.00 each'), findsOneWidget);
    // Row subtotal + footer grand total are the same amount here.
    expect(find.text('₱220.00'), findsNWidgets(2));
    expect(find.textContaining('Total '), findsOneWidget);
  });

  testWidgets('staged qty edits recompute subtotal and grand total live',
      (tester) async {
    final po = await seed();
    await pump(tester, po.id, UserRole.staff);
    await tester.tap(find.byIcon(LucideIcons.plus).first);
    await tester.pumpAndSettle();
    // 5 × ₱55 — row and footer both update before any write.
    expect(find.text('₱275.00'), findsNWidgets(2));
    final doc = await fake.collection('purchase_orders').doc(po.id).get();
    expect((doc.data()!['items'] as List).first['quantity'], 4,
        reason: 'recompute is local; nothing written yet');
  });

  testWidgets('cancelled PO keeps the grand total but drops all actions',
      (tester) async {
    final po = await seed();
    await repo.cancelPurchaseOrder(po.id);
    await pump(tester, po.id, UserRole.staff);
    expect(find.text('₱220.00'), findsNWidgets(2));
    expect(find.text('Share CSV'), findsNothing);
    expect(find.text('Mark ordered'), findsNothing);
  });

  testWidgets('item remove control is the × stepper button', (tester) async {
    final po = await seed();
    await pump(tester, po.id, UserRole.staff);
    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();
    expect(find.text('Last item — delete the purchase order instead'),
        findsOneWidget);
  });
}
