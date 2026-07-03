import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('PO-20260703-001'), findsOneWidget);
    expect(find.text('Brake Pad'), findsOneWidget);
    expect(find.text('Mark ordered'), findsOneWidget);
    expect(find.text('Receive'), findsNothing);
  });

  testWidgets('Mark ordered transitions to ordered with Receive',
      (tester) async {
    final po = await seed();
    await pump(tester, po.id, UserRole.staff);
    await tester.tap(find.text('Mark ordered'));
    await tester.pumpAndSettle();
    expect(find.text('Receive'), findsOneWidget);
    expect(find.text('Back to draft'), findsOneWidget);
  });

  testWidgets('Receive creates a linked draft receiving', (tester) async {
    final po = await seed(status: PurchaseOrderStatus.ordered);
    await pump(tester, po.id, UserRole.staff);
    await tester.tap(find.text('Receive'));
    await tester.pumpAndSettle();

    final receivings = await fake.collection('receivings').get();
    expect(receivings.size, 1);
    expect(receivings.docs.first.data()['purchaseOrderId'], po.id);
  });

  testWidgets('Delete is admin-only', (tester) async {
    final po = await seed();
    await pump(tester, po.id, UserRole.staff);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
