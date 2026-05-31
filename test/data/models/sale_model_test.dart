import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/models/sale_model.dart';
import 'package:maki_mobile_pos/data/models/sale_item_model.dart';
import 'package:maki_mobile_pos/data/models/labor_line_model.dart';

void main() {
  const item = SaleItemModel(
    id: 'item-1',
    productId: 'prod-1',
    sku: 'SKU-001',
    name: 'Spark Plug',
    unitPrice: 100.0,
    unitCost: 60.0,
    quantity: 2,
  );

  const labor = LaborLineModel(
    id: 'labor-1',
    description: 'Engine tune-up',
    fee: 450.0,
  );

  SaleModel buildModel() => SaleModel(
        id: 'sale-1',
        saleNumber: 'SALE-20260530-001',
        items: const [item],
        laborLines: const [labor],
        mechanicId: 'mech-1',
        mechanicName: 'Juan Dela Cruz',
        paymentMethod: PaymentMethod.cash,
        amountReceived: 650.0,
        changeGiven: 0.0,
        cashierId: 'cashier-1',
        cashierName: 'John Doe',
        createdAt: DateTime(2026, 5, 30),
      );

  group('SaleModel labor + mechanic', () {
    test('laborSubtotal sums fees; grandTotal adds labor to net parts', () {
      final model = buildModel();
      expect(model.laborSubtotal, 450.0);
      expect(model.grandTotal, 650.0); // 200 parts + 450 labor
    });

    test('toMap emits inline laborLines + mechanic fields', () {
      final map = buildModel().toMap();
      final laborMaps = map['laborLines'] as List<dynamic>;
      expect(laborMaps.length, 1);
      expect((laborMaps.first as Map<String, dynamic>)['fee'], 450.0);
      expect(map['mechanicId'], 'mech-1');
      expect(map['mechanicName'], 'Juan Dela Cruz');
    });

    test('fromMap parses laborLines DIRECTLY off the map, not via items param',
        () {
      // items come from the subcollection param; labor must come from the map
      final model = SaleModel.fromMap(
        {
          'saleNumber': 'SALE-20260530-001',
          'laborLines': [labor.toMap(includeId: true)],
          'mechanicId': 'mech-1',
          'mechanicName': 'Juan Dela Cruz',
          'discountType': 'amount',
          'paymentMethod': 'cash',
          'amountReceived': 650.0,
          'changeGiven': 0.0,
          'status': 'completed',
          'cashierId': 'cashier-1',
          'cashierName': 'John Doe',
        },
        'sale-1',
        items: const [item], // subcollection items only
      );

      expect(model.items.length, 1);
      expect(model.laborLines.length, 1);
      expect(model.laborLines.first.description, 'Engine tune-up');
      expect(model.mechanicId, 'mech-1');
      expect(model.mechanicName, 'Juan Dela Cruz');
    });

    test('fromMap defaults labor to [] and mechanic to null for legacy docs',
        () {
      final model = SaleModel.fromMap(
        {
          'saleNumber': 'SALE-LEGACY',
          'discountType': 'amount',
          'paymentMethod': 'cash',
          'amountReceived': 200.0,
          'changeGiven': 0.0,
          'status': 'completed',
          'cashierId': 'cashier-1',
          'cashierName': 'John Doe',
        },
        'sale-legacy',
        items: const [item],
      );

      expect(model.laborLines, isEmpty);
      expect(model.mechanicId, isNull);
      expect(model.mechanicName, isNull);
    });

    test('toEntity / fromEntity round-trips labor + mechanic', () {
      final entity = buildModel().toEntity();
      expect(entity.laborLines.single.fee, 450.0);
      expect(entity.mechanicId, 'mech-1');
      expect(entity.mechanicName, 'Juan Dela Cruz');

      final back = SaleModel.fromEntity(entity);
      expect(back.laborLines.single.description, 'Engine tune-up');
      expect(back.mechanicName, 'Juan Dela Cruz');
    });

    test('copyWith clearMechanic nulls mechanic fields', () {
      final cleared = buildModel().copyWith(clearMechanic: true);
      expect(cleared.mechanicId, isNull);
      expect(cleared.mechanicName, isNull);
      expect(cleared.laborLines.length, 1);
    });
  });
}
