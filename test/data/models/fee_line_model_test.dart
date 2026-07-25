import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('FeeLineModel', () {
    late FeeLineModel model;

    setUp(() {
      model = const FeeLineModel(
        id: 'fee-1',
        name: 'Electric charge',
        amount: 50.0,
      );
    });

    test('fromMap reads name and amount, id comes from documentId', () {
      final m = FeeLineModel.fromMap(
        {'name': 'Tire changer', 'amount': 30.0},
        'fee-9',
      );
      expect(m.id, 'fee-9');
      expect(m.name, 'Tire changer');
      expect(m.amount, 30.0);
    });

    test('fromMap defaults are safe for legacy/partial docs', () {
      final m = FeeLineModel.fromMap(<String, dynamic>{}, 'fee-x');
      expect(m.id, 'fee-x');
      expect(m.name, '');
      expect(m.amount, 0.0);
    });

    test('fromMap coerces an int amount to double', () {
      final m = FeeLineModel.fromMap(
        {'name': 'Air', 'amount': 10},
        'fee-int',
      );
      expect(m.amount, 10.0);
    });

    test('toMap omits id by default', () {
      final map = model.toMap();
      expect(map.containsKey('id'), isFalse);
      expect(map['name'], 'Electric charge');
      expect(map['amount'], 50.0);
    });

    test('toMap includes id when includeId is true', () {
      final map = model.toMap(includeId: true);
      expect(map['id'], 'fee-1');
      expect(map['name'], 'Electric charge');
      expect(map['amount'], 50.0);
    });

    test('toEntity maps all fields', () {
      final entity = model.toEntity();
      expect(entity, isA<FeeLineEntity>());
      expect(entity.id, 'fee-1');
      expect(entity.name, 'Electric charge');
      expect(entity.amount, 50.0);
    });

    test('fromEntity maps all fields', () {
      const entity = FeeLineEntity(
        id: 'fee-2',
        name: 'Tire changer',
        amount: 30.0,
      );
      final m = FeeLineModel.fromEntity(entity);
      expect(m.id, 'fee-2');
      expect(m.name, 'Tire changer');
      expect(m.amount, 30.0);
    });

    test('round-trips entity -> model -> map(includeId) -> model -> entity', () {
      const entity = FeeLineEntity(
        id: 'fee-3',
        name: 'Air',
        amount: 10.0,
      );
      final map = FeeLineModel.fromEntity(entity).toMap(includeId: true);
      final restored =
          FeeLineModel.fromMap(map, map['id'] as String).toEntity();
      expect(restored, entity);
    });
  });
}
