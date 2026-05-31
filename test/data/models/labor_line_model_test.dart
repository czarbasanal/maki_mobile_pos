import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('LaborLineModel', () {
    late LaborLineModel model;

    setUp(() {
      model = const LaborLineModel(
        id: 'labor-1',
        description: 'Engine tune-up',
        fee: 450.0,
      );
    });

    test('fromMap reads description and fee, id comes from documentId', () {
      final m = LaborLineModel.fromMap(
        {'description': 'Brake bleed', 'fee': 200.0},
        'labor-9',
      );
      expect(m.id, 'labor-9');
      expect(m.description, 'Brake bleed');
      expect(m.fee, 200.0);
    });

    test('fromMap defaults are safe for legacy/partial docs', () {
      final m = LaborLineModel.fromMap(<String, dynamic>{}, 'labor-x');
      expect(m.id, 'labor-x');
      expect(m.description, '');
      expect(m.fee, 0.0);
    });

    test('fromMap coerces an int fee to double', () {
      final m = LaborLineModel.fromMap(
        {'description': 'Oil change', 'fee': 300},
        'labor-int',
      );
      expect(m.fee, 300.0);
    });

    test('toMap omits id by default', () {
      final map = model.toMap();
      expect(map.containsKey('id'), isFalse);
      expect(map['description'], 'Engine tune-up');
      expect(map['fee'], 450.0);
    });

    test('toMap includes id when includeId is true', () {
      final map = model.toMap(includeId: true);
      expect(map['id'], 'labor-1');
      expect(map['description'], 'Engine tune-up');
      expect(map['fee'], 450.0);
    });

    test('toEntity maps all fields', () {
      final entity = model.toEntity();
      expect(entity, isA<LaborLineEntity>());
      expect(entity.id, 'labor-1');
      expect(entity.description, 'Engine tune-up');
      expect(entity.fee, 450.0);
    });

    test('fromEntity maps all fields', () {
      const entity = LaborLineEntity(
        id: 'labor-2',
        description: 'Chain adjust',
        fee: 150.0,
      );
      final m = LaborLineModel.fromEntity(entity);
      expect(m.id, 'labor-2');
      expect(m.description, 'Chain adjust');
      expect(m.fee, 150.0);
    });

    test('round-trips entity -> model -> map(includeId) -> model -> entity', () {
      const entity = LaborLineEntity(
        id: 'labor-3',
        description: 'Carb clean',
        fee: 320.0,
      );
      final map = LaborLineModel.fromEntity(entity).toMap(includeId: true);
      final restored =
          LaborLineModel.fromMap(map, map['id'] as String).toEntity();
      expect(restored, entity);
    });
  });
}
