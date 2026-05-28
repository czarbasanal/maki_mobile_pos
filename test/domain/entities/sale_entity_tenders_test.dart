import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/sale_entity.dart';
import 'package:maki_mobile_pos/domain/entities/sale_item_entity.dart';

SaleItemEntity _item({double price = 1000, int qty = 1}) => SaleItemEntity(
      id: 'i',
      productId: 'p',
      sku: 'SKU',
      name: 'Item',
      unitPrice: price,
      unitCost: 0,
      quantity: qty,
    );

SaleEntity _sale({
  required PaymentMethod method,
  Map<PaymentMethod, double> tenders = const {},
  double amountReceived = 1000,
}) =>
    SaleEntity(
      id: 's',
      saleNumber: 'SALE-1',
      items: [_item()],
      paymentMethod: method,
      tenders: tenders,
      amountReceived: amountReceived,
      changeGiven: 0,
      cashierId: 'c',
      cashierName: 'Cashier',
      createdAt: DateTime(2026, 5, 28),
    );

void main() {
  group('SaleEntity tenders', () {
    test('effectiveTenders falls back to {paymentMethod: grandTotal} when empty',
        () {
      final sale = _sale(method: PaymentMethod.gcash, tenders: const {});
      expect(sale.effectiveTenders, {PaymentMethod.gcash: 1000});
    });

    test('effectiveTenders returns the explicit breakdown when present', () {
      final sale = _sale(
        method: PaymentMethod.mixed,
        tenders: const {PaymentMethod.cash: 300, PaymentMethod.gcash: 700},
      );
      expect(sale.effectiveTenders,
          {PaymentMethod.cash: 300, PaymentMethod.gcash: 700});
    });

    test('cashCollected and salmonBalance read the right buckets', () {
      final salmon = _sale(
        method: PaymentMethod.salmon,
        tenders: const {PaymentMethod.cash: 400, PaymentMethod.salmon: 600},
      );
      expect(salmon.cashCollected, 400);
      expect(salmon.salmonBalance, 600);

      final gcashOnly = _sale(method: PaymentMethod.gcash, tenders: const {});
      expect(gcashOnly.cashCollected, 0); // gcash, not cash
      expect(gcashOnly.salmonBalance, 0);
    });

    test('isTenderValid requires tenders to sum to grandTotal', () {
      final ok = _sale(
        method: PaymentMethod.mixed,
        tenders: const {PaymentMethod.cash: 300, PaymentMethod.gcash: 700},
      );
      final bad = _sale(
        method: PaymentMethod.mixed,
        tenders: const {PaymentMethod.cash: 300, PaymentMethod.gcash: 500},
      );
      expect(ok.isTenderValid, true);
      expect(bad.isTenderValid, false);
      // Legacy (empty) is valid via effectiveTenders.
      expect(_sale(method: PaymentMethod.cash).isTenderValid, true);
    });
  });
}
