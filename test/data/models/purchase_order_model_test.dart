import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/purchase_order_model.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

void main() {
  PurchaseOrderEntity entity() => PurchaseOrderEntity(
        id: 'po1',
        referenceNumber: 'PO-20260703-001',
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
        status: PurchaseOrderStatus.ordered,
        notes: 'rush',
        createdAt: DateTime(2026, 7, 3, 10),
        createdBy: 'u1',
        createdByName: 'Admin',
        orderedAt: DateTime(2026, 7, 3, 11),
        receivingId: 'r1',
      );

  test('entity -> map -> entity round-trips every field', () {
    final map = PurchaseOrderModel.fromEntity(entity()).toMap();
    final back = PurchaseOrderModel.fromMap(map, 'po1').toEntity();
    expect(back, entity());
  });

  test('toMap(forCreate) uses a server timestamp for createdAt', () {
    final map = PurchaseOrderModel.fromEntity(entity()).toMap(forCreate: true);
    expect(map['createdAt'], isA<FieldValue>());
    expect(map['status'], 'ordered');
  });

  test('fromMap tolerates missing optionals and unknown status', () {
    final back = PurchaseOrderModel.fromMap({
      'referenceNumber': 'PO-X',
      'items': <dynamic>[],
      'createdAt': Timestamp.fromDate(DateTime(2026, 7, 1)),
    }, 'po2').toEntity();
    expect(back.status, PurchaseOrderStatus.draft);
    expect(back.supplierId, isNull);
    expect(back.orderedAt, isNull);
    expect(back.receivingId, isNull);
    expect(back.items, isEmpty);
  });
}
