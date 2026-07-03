import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/data/repositories/purchase_order_repository_impl.dart';
import 'package:maki_mobile_pos/data/repositories/receiving_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';

class _MockProductRepository extends Mock implements ProductRepository {}

void main() {
  late FakeFirebaseFirestore fake;
  late PurchaseOrderRepositoryImpl poRepo;
  late ReceivingRepositoryImpl receivingRepo;
  late _MockProductRepository productRepo;

  final product = ProductEntity(
    id: 'p1',
    sku: 'SKU-1',
    name: 'Brake Pad',
    cost: 55,
    costCode: 'NBF',
    price: 80,
    quantity: 2,
    reorderLevel: 2,
    unit: 'pcs',
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    fake = FakeFirebaseFirestore();
    poRepo = PurchaseOrderRepositoryImpl(firestore: fake);
    productRepo = _MockProductRepository();
    receivingRepo = ReceivingRepositoryImpl(
      firestore: fake,
      productRepository: productRepo,
    );
    when(() => productRepo.getProductById('p1'))
        .thenAnswer((_) async => product);
    when(() => productRepo.updateStock(
          productId: any(named: 'productId'),
          quantityChange: any(named: 'quantityChange'),
          updatedBy: any(named: 'updatedBy'),
          updatedByName: any(named: 'updatedByName'),
        )).thenAnswer((_) async => product);
  });

  Future<({String poId, String receivingId})> linkedPair() async {
    final po = await poRepo.createPurchaseOrder(PurchaseOrderEntity(
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
    await poRepo.markOrdered(po.id);
    final receivingId = await poRepo.startReceiving(
      purchaseOrderId: po.id,
      receivingReferenceNumber: 'RCV-20260703-001',
      createdBy: 'u1',
      createdByName: 'Admin',
    );
    return (poId: po.id, receivingId: receivingId);
  }

  test('completing a linked receiving marks the PO received', () async {
    final pair = await linkedPair();
    await receivingRepo.completeReceiving(
      receivingId: pair.receivingId,
      completedBy: 'u1',
      completedByName: 'Admin',
    );

    final po = await poRepo.getPurchaseOrderById(pair.poId);
    expect(po!.status, PurchaseOrderStatus.received);
    expect(po.receivedAt, isNotNull);
    expect(po.receivingId, pair.receivingId);

    final receiving = await receivingRepo.getReceivingById(pair.receivingId);
    expect(receiving!.status, ReceivingStatus.completed);
  });

  test('a deleted PO does not block completion', () async {
    final pair = await linkedPair();
    await poRepo.deletePurchaseOrder(pair.poId);

    await receivingRepo.completeReceiving(
      receivingId: pair.receivingId,
      completedBy: 'u1',
    );
    final receiving = await receivingRepo.getReceivingById(pair.receivingId);
    expect(receiving!.status, ReceivingStatus.completed);
  });

  test('cancelReceiving clears the PO link so Receive can retry', () async {
    final pair = await linkedPair();
    await receivingRepo.cancelReceiving(
      receivingId: pair.receivingId,
      cancelledBy: 'u1',
    );
    final po = await poRepo.getPurchaseOrderById(pair.poId);
    expect(po!.receivingId, isNull);
    expect(po.status, PurchaseOrderStatus.ordered);
  });

  test('deleteReceiving clears the PO link', () async {
    final pair = await linkedPair();
    await receivingRepo.deleteReceiving(pair.receivingId);
    final po = await poRepo.getPurchaseOrderById(pair.poId);
    expect(po!.receivingId, isNull);
  });

  test('unlinked receivings complete exactly as before', () async {
    final created = await receivingRepo.createReceiving(ReceivingEntity(
      id: '',
      referenceNumber: 'RCV-plain',
      items: const [
        ReceivingItemEntity(
          id: 'li-1',
          productId: 'p1',
          sku: 'SKU-1',
          name: 'Brake Pad',
          quantity: 3,
          unit: 'pcs',
          unitCost: 55,
          costCode: 'NBF',
        ),
      ],
      totalCost: 165,
      totalQuantity: 3,
      status: ReceivingStatus.draft,
      createdAt: DateTime(2026, 7, 3),
      createdBy: 'u1',
      createdByName: 'Admin',
    ));
    final done = await receivingRepo.completeReceiving(
      receivingId: created.id,
      completedBy: 'u1',
    );
    expect(done.status, ReceivingStatus.completed);
  });
}
