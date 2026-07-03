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

  PurchaseOrderItemEntity item() => const PurchaseOrderItemEntity(
        id: 'p1',
        productId: 'p1',
        sku: 'SKU-1',
        name: 'Brake Pad',
        quantity: 4,
        unit: 'pcs',
        unitCost: 55,
        costCode: 'NBF',
      );

  PurchaseOrderEntity draft({String ref = 'PO-20260703-001'}) =>
      PurchaseOrderEntity(
        id: '',
        referenceNumber: ref,
        supplierId: 'sup-1',
        supplierName: 'Acme',
        items: [item()],
        totalCost: 220,
        totalQuantity: 4,
        status: PurchaseOrderStatus.draft,
        createdAt: DateTime(2026, 7, 3),
        createdBy: 'u1',
        createdByName: 'Admin',
      );

  test('createPurchaseOrder -> getPurchaseOrderById round-trips items', () async {
    final created = await repo.createPurchaseOrder(draft());
    expect(created.id, isNotEmpty);

    final loaded = await repo.getPurchaseOrderById(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.referenceNumber, 'PO-20260703-001');
    expect(loaded.items, hasLength(1));
    expect(loaded.items.first.name, 'Brake Pad');
    expect(loaded.status, PurchaseOrderStatus.draft);
  });

  test('watchPurchaseOrders emits newest first', () async {
    await repo.createPurchaseOrder(draft());
    await repo.createPurchaseOrder(draft(ref: 'PO-20260703-002'));

    final list = await repo.watchPurchaseOrders().first;
    expect(list, hasLength(2));
  });

  test('watchPurchaseOrderById emits the doc and null for missing', () async {
    final created = await repo.createPurchaseOrder(draft());
    final po = await repo.watchPurchaseOrderById(created.id).first;
    expect(po!.referenceNumber, 'PO-20260703-001');

    final missing = await repo.watchPurchaseOrderById('nope').first;
    expect(missing, isNull);
  });

  test('updatePurchaseOrder rewrites items on a draft', () async {
    final created = await repo.createPurchaseOrder(draft());
    final updated = await repo.updatePurchaseOrder(
      created.copyWith(items: [item().copyWith(quantity: 9)]).recalculateTotals(),
    );
    expect(updated.items.first.quantity, 9);
    expect(updated.totalQuantity, 9);
  });

  test('updatePurchaseOrder rejects non-draft POs', () async {
    final created = await repo.createPurchaseOrder(draft());
    await fake
        .collection('purchase_orders')
        .doc(created.id)
        .update({'status': 'ordered'});

    expect(
      () => repo.updatePurchaseOrder(created.copyWith(notes: 'x')),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('generateReferenceNumber is PO-YYYYMMDD-NNN and increments', () async {
    final first = await repo.generateReferenceNumber();
    expect(first, matches(RegExp(r'^PO-\d{8}-001$')));

    await repo.createPurchaseOrder(draft().copyWith(createdAt: DateTime.now()));
    final second = await repo.generateReferenceNumber();
    expect(second, endsWith('-002'));
  });
}
