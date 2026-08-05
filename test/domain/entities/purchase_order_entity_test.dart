import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

void main() {
  PurchaseOrderItemEntity item({String id = 'p1', int qty = 2, double cost = 50, String unit = 'pcs'}) =>
      PurchaseOrderItemEntity(
        id: id,
        productId: id,
        sku: 'SKU-$id',
        name: 'Item $id',
        quantity: qty,
        unit: unit,
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

  group('sharedUnitOf', () {
    test('returns null for no units at all', () {
      expect(sharedUnitOf(const <String>[]), isNull);
    });

    test('returns the only unit when there is one', () {
      expect(sharedUnitOf(const ['set']), 'set');
    });

    test('returns the shared unit when every entry agrees', () {
      expect(sharedUnitOf(const ['set', 'set', 'set']), 'set');
    });

    test('returns null when entries disagree', () {
      expect(sharedUnitOf(const ['pcs', 'set']), isNull);
    });

    test('returns null when a later entry disagrees', () {
      expect(sharedUnitOf(const ['set', 'set', 'box']), isNull);
    });

    test('trims surrounding whitespace before comparing', () {
      expect(sharedUnitOf(const ['set', ' set ']), 'set');
    });

    test('returns null when any entry is blank — an unknown unit cannot agree', () {
      expect(sharedUnitOf(const ['set', '']), isNull);
      expect(sharedUnitOf(const ['   ']), isNull);
      expect(sharedUnitOf(const ['', 'set']), isNull);
    });
  });

  group('poQuantityLabel', () {
    test('appends the unit when there is one', () {
      expect(poQuantityLabel(12, 'set'), '12 set');
    });

    test('renders a bare count when there is no shared unit', () {
      expect(poQuantityLabel(12, null), '12');
    });

    test('leaves no trailing space on the bare form', () {
      expect(poQuantityLabel(12, null).endsWith(' '), isFalse);
    });
  });

  group('PurchaseOrderItemsTotals.sharedUnit', () {
    test('returns the unit when every item agrees', () {
      final items = [item(unit: 'set'), item(id: 'p2', unit: 'set')];
      expect(items.sharedUnit, 'set');
    });

    test('returns null when items disagree', () {
      final items = [item(unit: 'pcs'), item(id: 'p2', unit: 'set')];
      expect(items.sharedUnit, isNull);
    });

    test('returns null for an empty list', () {
      expect(<PurchaseOrderItemEntity>[].sharedUnit, isNull);
    });
  });
}
