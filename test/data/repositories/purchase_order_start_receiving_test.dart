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

  PurchaseOrderEntity draftEntity({String ref = 'PO-20260703-001'}) =>
      PurchaseOrderEntity(
        id: '',
        referenceNumber: ref,
        supplierId: 'sup-1',
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
      );

  Future<PurchaseOrderEntity> orderedPo() async {
    final po = await repo.createPurchaseOrder(draftEntity());
    await repo.markOrdered(po.id);
    return (await repo.getPurchaseOrderById(po.id))!;
  }

  Future<String> start(String poId) => repo.startReceiving(
        purchaseOrderId: poId,
        receivingReferenceNumber: 'RCV-20260703-001',
        createdBy: 'u1',
        createdByName: 'Admin',
      );

  test('creates a linked draft receiving prefilled from the PO', () async {
    final po = await orderedPo();
    final receivingId = await start(po.id);

    final receiving =
        await fake.collection('receivings').doc(receivingId).get();
    expect(receiving.exists, isTrue);
    expect(receiving.data()!['status'], 'draft');
    expect(receiving.data()!['purchaseOrderId'], po.id);
    expect(receiving.data()!['supplierName'], 'Acme');
    final items = receiving.data()!['items'] as List<dynamic>;
    expect(items, hasLength(1));
    expect((items.first as Map<String, dynamic>)['quantity'], 4);
    expect((items.first as Map<String, dynamic>)['unitCost'], 55);

    final linked = await repo.getPurchaseOrderById(po.id);
    expect(linked!.receivingId, receivingId);
    expect(linked.status, PurchaseOrderStatus.ordered,
        reason: 'received only when the receiving completes');
  });

  test('is idempotent while the linked receiving is still a draft', () async {
    final po = await orderedPo();
    final first = await start(po.id);
    final second = await start(po.id);
    expect(second, first);
    final receivings = await fake.collection('receivings').get();
    expect(receivings.size, 1);
  });

  test('creates a fresh receiving when the linked one was cancelled', () async {
    final po = await orderedPo();
    final first = await start(po.id);
    await fake
        .collection('receivings')
        .doc(first)
        .update({'status': 'cancelled'});

    final second = await start(po.id);
    expect(second, isNot(first));
  });

  test('rejects draft POs', () async {
    final po = await repo.createPurchaseOrder(draftEntity(ref: 'PO-X'));
    expect(() => start(po.id), throwsA(isA<DatabaseException>()));
  });
}
