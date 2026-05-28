import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/sale_entity.dart';
import 'package:maki_mobile_pos/domain/entities/sale_item_entity.dart';

SaleItemEntity _item(double price) => SaleItemEntity(
      id: 'i', productId: 'p', sku: 'S', name: 'N',
      unitPrice: price, unitCost: 0, quantity: 1,
    );

SaleEntity _sale(PaymentMethod method, Map<PaymentMethod, double> tenders,
        double price) =>
    SaleEntity(
      id: 's', saleNumber: 'X', items: [_item(price)],
      paymentMethod: method, tenders: tenders,
      amountReceived: price, changeGiven: 0,
      cashierId: 'c', cashierName: 'C', createdAt: DateTime(2026, 5, 28),
    );

/// Mirrors the summation in SaleRepositoryImpl.getSalesSummary.
Map<PaymentMethod, double> sumTenders(List<SaleEntity> sales) {
  final result = <PaymentMethod, double>{};
  for (final m in const [
    PaymentMethod.cash,
    PaymentMethod.gcash,
    PaymentMethod.maya,
    PaymentMethod.salmon,
  ]) {
    result[m] = 0;
  }
  for (final sale in sales) {
    sale.effectiveTenders.forEach((method, amount) {
      result[method] = (result[method] ?? 0) + amount;
    });
  }
  return result;
}

void main() {
  test('mixed splits across cash + digital; salmon balance to salmon bucket',
      () {
    final sales = [
      _sale(PaymentMethod.mixed,
          {PaymentMethod.cash: 300, PaymentMethod.gcash: 700}, 1000),
      _sale(PaymentMethod.salmon,
          {PaymentMethod.cash: 400, PaymentMethod.salmon: 600}, 1000),
      _sale(PaymentMethod.cash, const {}, 500), // legacy single cash
    ];

    final b = sumTenders(sales);
    expect(b[PaymentMethod.cash], 300 + 400 + 500);
    expect(b[PaymentMethod.gcash], 700);
    expect(b[PaymentMethod.salmon], 600);
    expect(b.containsKey(PaymentMethod.mixed), false);

    final total = b.values.fold<double>(0, (a, x) => a + x);
    expect(total, 1000 + 1000 + 500); // == sum of grandTotals (netAmount)
  });
}
