import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/purchase_order_csv.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

void main() {
  final po = PurchaseOrderEntity(
    id: 'po1',
    referenceNumber: 'PO-20260703-001',
    supplierName: 'Acme, Inc.',
    items: const [
      PurchaseOrderItemEntity(
        id: 'p1',
        productId: 'p1',
        sku: 'SKU-1',
        name: 'Brake "HD" Pad',
        quantity: 4,
        unit: 'pcs',
        unitCost: 55,
        costCode: 'NBF',
      ),
    ],
    totalCost: 220,
    totalQuantity: 4,
    status: PurchaseOrderStatus.ordered,
    createdAt: DateTime(2026, 7, 3),
    createdBy: 'u1',
    createdByName: 'Admin',
  );

  test('builds header block and item rows without costs', () {
    final lines = buildPurchaseOrderCsv(po).trim().split('\n');
    expect(lines[0], 'Purchase Order,PO-20260703-001');
    expect(lines[1], 'Supplier,"Acme, Inc."');
    expect(lines[2], 'Date,2026-07-03');
    expect(lines[3], '');
    expect(lines[4], 'SKU,Name,Qty,Unit');
    expect(lines[5], 'SKU-1,"Brake ""HD"" Pad",4,pcs');
    expect(buildPurchaseOrderCsv(po), isNot(contains('55')),
        reason: 'costs must not leak into the shared file');
  });

  test('null supplier renders as No supplier', () {
    final noSup = po.copyWith(clearSupplierName: true);
    expect(buildPurchaseOrderCsv(noSup), contains('Supplier,No supplier'));
  });

  test('CSV never carries currency or cost columns (totals stay UI-only)', () {
    final csv = buildPurchaseOrderCsv(po);
    expect(csv, isNot(contains('₱')));
    expect(csv.toLowerCase(), isNot(contains('cost')));
    expect(csv.toLowerCase(), isNot(contains('total')));
    expect(csv, contains('SKU,Name,Qty,Unit'));
  });
}
