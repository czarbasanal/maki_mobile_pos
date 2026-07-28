import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/models/sale_model.dart';
import 'package:maki_mobile_pos/data/models/sale_item_model.dart';
import 'package:maki_mobile_pos/data/models/labor_line_model.dart';
import 'package:maki_mobile_pos/data/models/fee_line_model.dart';

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

  const fee = FeeLineModel(
    id: 'fee-1',
    name: 'Electric charge',
    amount: 20.0,
  );

  SaleModel buildModel() => SaleModel(
        id: 'sale-1',
        saleNumber: 'SALE-20260530-001',
        items: const [item],
        laborLines: const [labor],
        feeLines: const [fee],
        mechanicId: 'mech-1',
        mechanicName: 'Juan Dela Cruz',
        paymentMethod: PaymentMethod.cash,
        amountReceived: 670.0,
        changeGiven: 0.0,
        cashierId: 'cashier-1',
        cashierName: 'John Doe',
        createdAt: DateTime(2026, 5, 30),
      );

  group('SaleModel labor + mechanic', () {
    test('laborSubtotal sums fees; grandTotal adds labor + fees to net parts',
        () {
      final model = buildModel();
      expect(model.laborSubtotal, 450.0);
      expect(model.grandTotal, 670.0); // 200 parts + 450 labor + 20 fees
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

    // Transition guard for the drafts→job_orders migration: sales written by
    // +17 APKs carry the OLD field name. Deleting this fallback before every
    // phone is on +18 (and the migration's final sweep has run) silently
    // severs the sale↔ticket link on every pre-migration sale.
    test('fromMap reads a pre-migration draftId as jobOrderId', () {
      final model = SaleModel.fromMap(
        {'saleNumber': 'SALE-OLD', 'draftId': 'ticket-1'},
        'sale-old',
      );

      expect(model.jobOrderId, 'ticket-1');
    });

    test('fromMap prefers jobOrderId when a doc carries both fields', () {
      final model = SaleModel.fromMap(
        {
          'saleNumber': 'SALE-BOTH',
          'jobOrderId': 'ticket-new',
          'draftId': 'ticket-old',
        },
        'sale-both',
      );

      expect(model.jobOrderId, 'ticket-new');
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

  group('SaleModel fee lines', () {
    test('toMap emits inline feeLines', () {
      final map = buildModel().toMap();
      final feeMaps = map['feeLines'] as List<dynamic>;
      expect(feeMaps.length, 1);
      final f = feeMaps.first as Map<String, dynamic>;
      expect(f['id'], 'fee-1');
      expect(f['name'], 'Electric charge');
      expect(f['amount'], 20.0);
    });

    test('fromMap parses feeLines DIRECTLY off the map, not via items param',
        () {
      final model = SaleModel.fromMap(
        {
          'saleNumber': 'SALE-20260530-001',
          'feeLines': [fee.toMap(includeId: true)],
          'discountType': 'amount',
          'paymentMethod': 'cash',
          'amountReceived': 220.0,
          'changeGiven': 0.0,
          'status': 'completed',
          'cashierId': 'cashier-1',
          'cashierName': 'John Doe',
        },
        'sale-1',
        items: const [item],
      );

      expect(model.feeLines.length, 1);
      expect(model.feeLines.first.name, 'Electric charge');
      expect(model.feeLines.first.amount, 20.0);
    });

    test('fromMap defaults feeLines to [] for legacy docs (no feeLines key)',
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

      expect(model.feeLines, isEmpty);
    });

    test('toEntity / fromEntity round-trips feeLines', () {
      final entity = buildModel().toEntity();
      expect(entity.feeLines.single.amount, 20.0);
      expect(entity.feeLines.single.name, 'Electric charge');

      final back = SaleModel.fromEntity(entity);
      expect(back.feeLines.single.name, 'Electric charge');
      expect(back.feeLines.single.amount, 20.0);
    });

    test('feeLines description round-trips through toMap/fromMap/toEntity', () {
      const chargeItemFee = FeeLineModel(
        id: 'fee-2',
        name: 'Charge Item',
        amount: 100.0,
        description: 'Battery replacement',
      );
      final model = SaleModel(
        id: 'sale-2',
        saleNumber: 'SALE-20260530-002',
        items: const [item],
        feeLines: const [chargeItemFee],
        paymentMethod: PaymentMethod.cash,
        amountReceived: 300.0,
        changeGiven: 0.0,
        cashierId: 'cashier-1',
        cashierName: 'John Doe',
        createdAt: DateTime(2026, 5, 30),
      );

      final map = model.toMap();
      final feeMap =
          (map['feeLines'] as List<dynamic>).first as Map<String, dynamic>;
      expect(feeMap['description'], 'Battery replacement');

      final restored = SaleModel.fromMap(map, 'sale-2', items: const [item]);
      expect(restored.feeLines.single.description, 'Battery replacement');
      expect(restored.toEntity().feeLines.single.description,
          'Battery replacement');
    });
  });

  group('motorcycleModel', () {
    test('round-trips through fromMap/toMap/toEntity', () {
      final map = {
        'saleNumber': 'S-1',
        'paymentMethod': 'cash',
        'amountReceived': 100.0,
        'changeGiven': 0.0,
        'status': 'completed',
        'cashierId': 'u1',
        'cashierName': 'C',
        'motorcycleModel': 'Sniper 150',
      };
      final model = SaleModel.fromMap(map, 's1');
      expect(model.motorcycleModel, 'Sniper 150');
      expect(model.toMap()['motorcycleModel'], 'Sniper 150');
      expect(model.toEntity().motorcycleModel, 'Sniper 150');
    });

    test('is null when absent (legacy sale)', () {
      final model = SaleModel.fromMap(
        {
          'saleNumber': 'S-2',
          'paymentMethod': 'cash',
          'amountReceived': 0.0,
          'changeGiven': 0.0,
          'status': 'completed',
          'cashierId': 'u',
          'cashierName': 'C',
        },
        's2',
      );
      expect(model.motorcycleModel, isNull);
      expect(model.toMap()['motorcycleModel'], isNull);
    });
  });
}
