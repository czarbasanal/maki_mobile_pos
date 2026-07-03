import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/purchase_order_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

/// PO lifecycle transitions must clean up the in-flight linked receiving
/// draft — otherwise an orphan draft "From PO-…" can still be completed and
/// add stock for an order that was cancelled, deleted, or re-edited.
void main() {
  late FakeFirebaseFirestore fake;
  late PurchaseOrderRepositoryImpl repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = PurchaseOrderRepositoryImpl(firestore: fake);
  });

  Future<({String poId, String receivingId})> orderedWithDraft() async {
    final po = await repo.createPurchaseOrder(PurchaseOrderEntity(
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
    ));
    await repo.markOrdered(po.id);
    final receivingId = await repo.startReceiving(
      purchaseOrderId: po.id,
      receivingReferenceNumber: 'RCV-20260703-001',
      createdBy: 'u1',
      createdByName: 'Admin',
    );
    return (poId: po.id, receivingId: receivingId);
  }

  Future<String?> receivingStatus(String id) async =>
      (await fake.collection('receivings').doc(id).get()).data()?['status']
          as String?;

  test('cancelPurchaseOrder cancels the linked draft receiving', () async {
    final pair = await orderedWithDraft();
    await repo.cancelPurchaseOrder(pair.poId);

    expect(await receivingStatus(pair.receivingId), 'cancelled',
        reason: 'the orphan draft must not stay completable');
    final po = await repo.getPurchaseOrderById(pair.poId);
    expect(po!.status, PurchaseOrderStatus.cancelled);
    expect(po.receivingId, isNull);
  });

  test('revertToDraft cancels the stale draft and clears the link', () async {
    final pair = await orderedWithDraft();
    await repo.revertToDraft(pair.poId);

    expect(await receivingStatus(pair.receivingId), 'cancelled',
        reason: 'stale snapshot must not be resumable after re-editing');
    final po = await repo.getPurchaseOrderById(pair.poId);
    expect(po!.status, PurchaseOrderStatus.draft);
    expect(po.receivingId, isNull,
        reason: 'a later Receive must build a fresh receiving');
  });

  test('deletePurchaseOrder cancels the linked draft receiving', () async {
    final pair = await orderedWithDraft();
    await repo.deletePurchaseOrder(pair.poId);

    expect(await receivingStatus(pair.receivingId), 'cancelled');
    expect(await repo.getPurchaseOrderById(pair.poId), isNull);
  });

  test('transitions leave a completed linked receiving untouched', () async {
    final pair = await orderedWithDraft();
    await fake
        .collection('receivings')
        .doc(pair.receivingId)
        .update({'status': 'completed'});

    // PO still ordered with receivingId set; cancel must not touch the
    // completed receiving.
    await repo.cancelPurchaseOrder(pair.poId);
    expect(await receivingStatus(pair.receivingId), 'completed');
  });
}
