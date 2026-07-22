import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/stock_totals.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

ProductEntity _p({required double cost, required double price, required int qty}) =>
    ProductEntity(
      id: 'x',
      sku: 'X-1',
      name: 'X',
      costCode: 'S',
      cost: cost,
      price: price,
      quantity: qty,
      reorderLevel: 0,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026),
    );

void main() {
  test('empty list is all zeros', () {
    final t = StockTotals.of(const []);
    expect(t.cost, 0);
    expect(t.retail, 0);
    expect(t.profit, 0);
  });

  test('sums cost*qty and price*qty; profit is the difference', () {
    final t = StockTotals.of([
      _p(cost: 100, price: 250, qty: 2),
      _p(cost: 50, price: 80, qty: 10),
    ]);
    expect(t.cost, 700);
    expect(t.retail, 1300);
    expect(t.profit, 600);
  });

  test('zero quantity contributes nothing', () {
    final t = StockTotals.of([_p(cost: 999, price: 1999, qty: 0)]);
    expect(t.cost, 0);
    expect(t.retail, 0);
  });
}
