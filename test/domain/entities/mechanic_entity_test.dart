import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('MechanicEntity', () {
    late MechanicEntity mechanic;

    setUp(() {
      mechanic = MechanicEntity(
        id: 'mech-1',
        name: 'Juan Dela Cruz',
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
        createdBy: 'admin-1',
      );
    });

    test('holds its fields', () {
      expect(mechanic.id, 'mech-1');
      expect(mechanic.name, 'Juan Dela Cruz');
      expect(mechanic.isActive, true);
      expect(mechanic.createdAt, DateTime(2026, 5, 30));
      expect(mechanic.createdBy, 'admin-1');
      expect(mechanic.updatedAt, isNull);
      expect(mechanic.updatedBy, isNull);
    });

    test('copyWith overrides only the given fields', () {
      final updated = mechanic.copyWith(name: 'Pedro', isActive: false);
      expect(updated.name, 'Pedro');
      expect(updated.isActive, false);
      expect(updated.id, 'mech-1');
      expect(updated.createdAt, DateTime(2026, 5, 30));
    });

    test('equality is value-based via props', () {
      final same = MechanicEntity(
        id: 'mech-1',
        name: 'Juan Dela Cruz',
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
        createdBy: 'admin-1',
      );
      expect(mechanic, equals(same));
      expect(mechanic, isNot(equals(mechanic.copyWith(name: 'X'))));
    });

    test('empty() produces a blank active mechanic', () {
      final empty = MechanicEntity.empty();
      expect(empty.id, '');
      expect(empty.name, '');
      expect(empty.isActive, true);
    });
  });
}
