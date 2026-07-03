import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

void main() {
  PurchaseOrderItemEntity item({String id = 'p1', int qty = 2, double cost = 50}) =>
      PurchaseOrderItemEntity(
        id: id,
        productId: id,
        sku: 'SKU-$id',
        name: 'Item $id',
        quantity: qty,
        unit: 'pcs',
        unitCost: cost,
        costCode: 'AB',
      );

  PurchaseOrderEntity po({PurchaseOrderStatus status = PurchaseOrderStatus.draft}) =>
      PurchaseOrderEntity(
        id: 'po1',
        referenceNumber: 'PO-20260703-001',
        supplierId: 'sup-1',
        supplierName: 'Acme',
        items: [item(), item(id: 'p2', qty: 3, cost: 10)],
        totalCost: 0,
        totalQuantity: 0,
        status: status,
        createdAt: DateTime(2026, 7, 3),
        createdBy: 'u1',
        createdByName: 'Admin',
      );

  test('recalculateTotals sums cost and quantity from items', () {
    final r = po().recalculateTotals();
    expect(r.totalCost, 2 * 50 + 3 * 10);
    expect(r.totalQuantity, 5);
  });

  test('item totalCost is unitCost × quantity', () {
    expect(item(qty: 3, cost: 12.5).totalCost, 37.5);
  });

  test('status helpers: draft edits, ordered receives, terminal states do neither', () {
    expect(po().isDraft, isTrue);
    expect(po().canEdit, isTrue);
    expect(po().canReceive, isFalse);
    expect(po(status: PurchaseOrderStatus.ordered).canReceive, isTrue);
    expect(po(status: PurchaseOrderStatus.ordered).canEdit, isFalse);
    expect(po(status: PurchaseOrderStatus.received).canReceive, isFalse);
    expect(po(status: PurchaseOrderStatus.cancelled).canEdit, isFalse);
  });

  test('copyWith clear flags null out optional fields', () {
    final linked = po().copyWith(receivingId: 'r1', orderedAt: DateTime(2026, 7, 4));
    expect(linked.receivingId, 'r1');
    final cleared = linked.copyWith(clearReceivingId: true, clearOrderedAt: true);
    expect(cleared.receivingId, isNull);
    expect(cleared.orderedAt, isNull);
    expect(cleared.referenceNumber, 'PO-20260703-001');
  });
}
