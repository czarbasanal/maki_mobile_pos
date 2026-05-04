import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/utils/top_selling.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

SaleItemEntity _item({
  String productId = 'p',
  String sku = 'SKU',
  String name = 'Item',
  int quantity = 1,
  double unitPrice = 100,
  double unitCost = 60,
}) {
  return SaleItemEntity(
    id: '$productId-line',
    productId: productId,
    sku: sku,
    name: name,
    unitPrice: unitPrice,
    unitCost: unitCost,
    quantity: quantity,
  );
}

SaleEntity _sale({
  String id = 's',
  required List<SaleItemEntity> items,
  SaleStatus status = SaleStatus.completed,
}) {
  return SaleEntity(
    id: id,
    saleNumber: id.toUpperCase(),
    items: items,
    paymentMethod: PaymentMethod.cash,
    amountReceived: 0,
    changeGiven: 0,
    status: status,
    cashierId: 'u',
    cashierName: 'Cashier',
    createdAt: DateTime(2026, 5, 4, 10),
  );
}

void main() {
  group('topSellingFromSales', () {
    test('returns empty when there are no sales', () {
      expect(topSellingFromSales(const []), isEmpty);
    });

    test('aggregates quantity and revenue across multiple sales', () {
      final sales = [
        _sale(id: 's1', items: [
          _item(productId: 'p1', name: 'Apple', quantity: 2, unitPrice: 50),
          _item(productId: 'p2', name: 'Banana', quantity: 1, unitPrice: 30),
        ]),
        _sale(id: 's2', items: [
          _item(productId: 'p1', name: 'Apple', quantity: 3, unitPrice: 50),
        ]),
      ];

      final ranked = topSellingFromSales(sales);
      expect(ranked, hasLength(2));

      // p1: 2+3 = 5 units, revenue 250
      expect(ranked.first.productId, 'p1');
      expect(ranked.first.quantitySold, 5);
      expect(ranked.first.totalRevenue, 250);

      // p2: 1 unit, revenue 30
      expect(ranked[1].productId, 'p2');
      expect(ranked[1].quantitySold, 1);
      expect(ranked[1].totalRevenue, 30);
    });

    test('orders by quantity descending', () {
      final sales = [
        _sale(items: [
          _item(productId: 'low', quantity: 1),
          _item(productId: 'high', quantity: 10),
          _item(productId: 'mid', quantity: 5),
        ]),
      ];

      final ranked = topSellingFromSales(sales);
      expect(ranked.map((r) => r.productId).toList(),
          ['high', 'mid', 'low']);
    });

    test('breaks ties on quantity by total revenue', () {
      // Both products sold 3 units, but A is at 100/unit and B at 50/unit.
      final sales = [
        _sale(items: [
          _item(productId: 'B', quantity: 3, unitPrice: 50),
          _item(productId: 'A', quantity: 3, unitPrice: 100),
        ]),
      ];

      final ranked = topSellingFromSales(sales);
      expect(ranked.map((r) => r.productId).toList(), ['A', 'B']);
    });

    test('excludes voided sales from the ranking', () {
      final sales = [
        _sale(id: 'good', items: [
          _item(productId: 'p1', quantity: 2),
        ]),
        _sale(
          id: 'voided',
          items: [_item(productId: 'p1', quantity: 100)],
          status: SaleStatus.voided,
        ),
      ];

      final ranked = topSellingFromSales(sales);
      expect(ranked, hasLength(1));
      expect(ranked.first.quantitySold, 2);
    });

    test('preserves the most recent product name/sku snapshots from the sale',
        () {
      final sales = [
        _sale(items: [
          _item(productId: 'p1', sku: 'SKU-001', name: 'Apple', quantity: 1),
        ]),
      ];

      final ranked = topSellingFromSales(sales);
      expect(ranked.first.sku, 'SKU-001');
      expect(ranked.first.name, 'Apple');
    });
  });
}
