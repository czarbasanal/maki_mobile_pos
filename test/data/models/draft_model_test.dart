import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/draft_model.dart';
import 'package:maki_mobile_pos/data/models/labor_line_model.dart';
import 'package:maki_mobile_pos/data/models/fee_line_model.dart';
import 'package:maki_mobile_pos/data/models/sale_item_model.dart';

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

  DraftModel buildModel() => DraftModel(
        id: 'draft-1',
        name: 'Service Job',
        items: const [item],
        laborLines: const [labor],
        feeLines: const [fee],
        mechanicId: 'mech-1',
        mechanicName: 'Juan Dela Cruz',
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime(2026, 5, 30),
      );

  group('DraftModel labor + mechanic', () {
    test(
        'laborSubtotal sums labor fees; grandTotal adds labor + fees to net parts',
        () {
      final model = buildModel();
      expect(model.laborSubtotal, 450.0);
      // parts: 100*2 = 200, no discount; +450 labor +20 fees
      expect(model.grandTotal, 670.0);
    });

    test('toMap emits inline laborLines + mechanic fields', () {
      final map = buildModel().toMap();
      final laborMaps = map['laborLines'] as List<dynamic>;
      expect(laborMaps.length, 1);
      final l = laborMaps.first as Map<String, dynamic>;
      expect(l['id'], 'labor-1');
      expect(l['description'], 'Engine tune-up');
      expect(l['fee'], 450.0);
      expect(map['mechanicId'], 'mech-1');
      expect(map['mechanicName'], 'Juan Dela Cruz');
    });

    test('fromMap parses laborLines array + mechanic fields', () {
      final model = DraftModel.fromMap({
        'name': 'Service Job',
        'items': [item.toMap(includeId: true)],
        'laborLines': [labor.toMap(includeId: true)],
        'mechanicId': 'mech-1',
        'mechanicName': 'Juan Dela Cruz',
        'discountType': 'amount',
        'createdBy': 'cashier-1',
        'createdByName': 'John Doe',
      }, 'draft-1');

      expect(model.laborLines.length, 1);
      expect(model.laborLines.first.description, 'Engine tune-up');
      expect(model.laborLines.first.fee, 450.0);
      expect(model.mechanicId, 'mech-1');
      expect(model.mechanicName, 'Juan Dela Cruz');
    });

    test('fromMap defaults labor to [] and mechanic to null for legacy docs',
        () {
      final model = DraftModel.fromMap({
        'name': 'Legacy Draft',
        'items': [item.toMap(includeId: true)],
        'discountType': 'amount',
        'createdBy': 'cashier-1',
        'createdByName': 'John Doe',
      }, 'draft-legacy');

      expect(model.laborLines, isEmpty);
      expect(model.mechanicId, isNull);
      expect(model.mechanicName, isNull);
    });

    test('toEntity / fromEntity round-trips labor + mechanic', () {
      final entity = buildModel().toEntity();
      expect(entity.laborLines.single.description, 'Engine tune-up');
      expect(entity.mechanicId, 'mech-1');
      expect(entity.mechanicName, 'Juan Dela Cruz');

      final back = DraftModel.fromEntity(entity);
      expect(back.laborLines.single.fee, 450.0);
      expect(back.mechanicId, 'mech-1');
      expect(back.mechanicName, 'Juan Dela Cruz');
    });

    test('copyWith clearMechanic nulls mechanic fields', () {
      final cleared = buildModel().copyWith(clearMechanic: true);
      expect(cleared.mechanicId, isNull);
      expect(cleared.mechanicName, isNull);
      // labor untouched
      expect(cleared.laborLines.length, 1);
    });
  });

  group('DraftModel fee lines', () {
    test('toMap emits inline feeLines', () {
      final map = buildModel().toMap();
      final feeMaps = map['feeLines'] as List<dynamic>;
      expect(feeMaps.length, 1);
      final f = feeMaps.first as Map<String, dynamic>;
      expect(f['id'], 'fee-1');
      expect(f['name'], 'Electric charge');
      expect(f['amount'], 20.0);
    });

    test('fromMap parses feeLines array', () {
      final model = DraftModel.fromMap({
        'name': 'Service Job',
        'items': [item.toMap(includeId: true)],
        'feeLines': [fee.toMap(includeId: true)],
        'discountType': 'amount',
        'createdBy': 'cashier-1',
        'createdByName': 'John Doe',
      }, 'draft-1');

      expect(model.feeLines.length, 1);
      expect(model.feeLines.first.name, 'Electric charge');
      expect(model.feeLines.first.amount, 20.0);
    });

    test('fromMap defaults feeLines to [] for legacy docs (no feeLines key)',
        () {
      final model = DraftModel.fromMap({
        'name': 'Legacy Draft',
        'items': [item.toMap(includeId: true)],
        'discountType': 'amount',
        'createdBy': 'cashier-1',
        'createdByName': 'John Doe',
      }, 'draft-legacy');

      expect(model.feeLines, isEmpty);
    });

    test('toEntity / fromEntity round-trips feeLines', () {
      final entity = buildModel().toEntity();
      expect(entity.feeLines.single.name, 'Electric charge');
      expect(entity.feeLines.single.amount, 20.0);

      final back = DraftModel.fromEntity(entity);
      expect(back.feeLines.single.name, 'Electric charge');
      expect(back.feeLines.single.amount, 20.0);
    });
  });

  group('motorcycleModel', () {
    test('round-trips through fromMap/toMap', () {
      final map = {
        'name': 'ABC-123',
        'items': <dynamic>[],
        'motorcycleModel': 'Nmax',
        'createdBy': 'u1',
        'createdByName': 'Cashier',
      };
      final model = DraftModel.fromMap(map, 'd1');
      expect(model.motorcycleModel, 'Nmax');
      expect(model.toMap()['motorcycleModel'], 'Nmax');
      expect(model.toEntity().motorcycleModel, 'Nmax');
    });

    test('is null when the key is absent (legacy/web draft)', () {
      final model = DraftModel.fromMap(
        {
          'name': 'X',
          'items': <dynamic>[],
          'createdBy': 'u1',
          'createdByName': 'C',
        },
        'd2',
      );
      expect(model.motorcycleModel, isNull);
      expect(model.toMap()['motorcycleModel'], isNull);
    });
  });
}
