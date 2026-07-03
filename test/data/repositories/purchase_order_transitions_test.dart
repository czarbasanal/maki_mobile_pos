import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/purchase_order_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

void main() {
  late FakeFirebaseFirestore fake;
  late PurchaseOrderRepositoryImpl repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = PurchaseOrderRepositoryImpl(firestore: fake);
  });

  Future<PurchaseOrderEntity> seed() => repo.createPurchaseOrder(
        PurchaseOrderEntity(
          id: '',
          referenceNumber: 'PO-20260703-001',
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
        ),
      );

  test('markOrdered: draft -> ordered with orderedAt', () async {
    final po = await seed();
    await repo.markOrdered(po.id);
    final loaded = await repo.getPurchaseOrderById(po.id);
    expect(loaded!.status, PurchaseOrderStatus.ordered);
    expect(loaded.orderedAt, isNotNull);
  });

  test('markOrdered rejects non-draft', () async {
    final po = await seed();
    await repo.markOrdered(po.id);
    expect(() => repo.markOrdered(po.id), throwsA(isA<DatabaseException>()));
  });

  test('revertToDraft: ordered -> draft clearing orderedAt', () async {
    final po = await seed();
    await repo.markOrdered(po.id);
    await repo.revertToDraft(po.id);
    final loaded = await repo.getPurchaseOrderById(po.id);
    expect(loaded!.status, PurchaseOrderStatus.draft);
    expect(loaded.orderedAt, isNull);
  });

  test('revertToDraft rejects a draft', () async {
    final po = await seed();
    expect(() => repo.revertToDraft(po.id), throwsA(isA<DatabaseException>()));
  });

  test('cancel allowed from draft and ordered, not from cancelled', () async {
    final po = await seed();
    await repo.cancelPurchaseOrder(po.id);
    final loaded = await repo.getPurchaseOrderById(po.id);
    expect(loaded!.status, PurchaseOrderStatus.cancelled);
    expect(() => repo.cancelPurchaseOrder(po.id),
        throwsA(isA<DatabaseException>()));
  });

  test('delete removes the doc', () async {
    final po = await seed();
    await repo.deletePurchaseOrder(po.id);
    expect(await repo.getPurchaseOrderById(po.id), isNull);
  });
}
