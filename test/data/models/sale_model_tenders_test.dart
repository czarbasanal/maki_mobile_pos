import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/models/sale_model.dart';

void main() {
  group('SaleModel tenders', () {
    test('serializes and reads back the tender map', () {
      final model = SaleModel.fromMap({
        'saleNumber': 'SALE-1',
        'paymentMethod': 'mixed',
        'tenders': {'cash': 300, 'gcash': 700},
        'amountReceived': 1000,
        'changeGiven': 0,
      }, 'doc-1');

      expect(model.tenders, {
        PaymentMethod.cash: 300.0,
        PaymentMethod.gcash: 700.0,
      });
      expect(model.toMap()['tenders'], {'cash': 300.0, 'gcash': 700.0});
      expect(model.toEntity().tenders, {
        PaymentMethod.cash: 300.0,
        PaymentMethod.gcash: 700.0,
      });
    });

    test('legacy doc without tenders yields an empty map', () {
      final model = SaleModel.fromMap({
        'saleNumber': 'SALE-2',
        'paymentMethod': 'cash',
        'amountReceived': 500,
      }, 'doc-2');

      expect(model.tenders, isEmpty);
      // toMap omits an empty tenders map.
      expect(model.toMap().containsKey('tenders'), false);
    });

    test('round-trips a salmon breakdown via fromEntity', () {
      final entity = SaleModel.fromMap({
        'saleNumber': 'SALE-3',
        'paymentMethod': 'salmon',
        'tenders': {'cash': 400, 'salmon': 600},
      }, 'doc-3').toEntity();

      final back = SaleModel.fromEntity(entity);
      expect(back.tenders,
          {PaymentMethod.cash: 400.0, PaymentMethod.salmon: 600.0});
    });
  });
}
