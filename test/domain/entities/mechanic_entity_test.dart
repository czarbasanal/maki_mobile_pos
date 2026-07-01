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
        address: '123 Rizal St, Cebu',
        contactNumber: '0917 123 4567',
        createdAt: DateTime(2026, 5, 30),
        createdBy: 'admin-1',
      );
    });

    test('holds its fields', () {
      expect(mechanic.id, 'mech-1');
      expect(mechanic.name, 'Juan Dela Cruz');
      expect(mechanic.isActive, true);
      expect(mechanic.address, '123 Rizal St, Cebu');
      expect(mechanic.contactNumber, '0917 123 4567');
      expect(mechanic.createdAt, DateTime(2026, 5, 30));
      expect(mechanic.createdBy, 'admin-1');
      expect(mechanic.updatedAt, isNull);
      expect(mechanic.updatedBy, isNull);
    });

    test('address + contactNumber default to null', () {
      final m = MechanicEntity(
        id: 'm',
        name: 'No Contact',
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      );
      expect(m.address, isNull);
      expect(m.contactNumber, isNull);
    });

    test('copyWith overrides only the given fields', () {
      final updated = mechanic.copyWith(
        name: 'Pedro',
        isActive: false,
        address: '456 Mabini St',
        contactNumber: '0999 000 1111',
      );
      expect(updated.name, 'Pedro');
      expect(updated.isActive, false);
      expect(updated.address, '456 Mabini St');
      expect(updated.contactNumber, '0999 000 1111');
      expect(updated.id, 'mech-1');
      expect(updated.createdAt, DateTime(2026, 5, 30));
    });

    test('copyWith preserves address/contactNumber when not passed', () {
      final updated = mechanic.copyWith(name: 'Pedro');
      expect(updated.address, '123 Rizal St, Cebu');
      expect(updated.contactNumber, '0917 123 4567');
    });

    test('copyWith clears address/contactNumber via clear flags', () {
      final cleared = mechanic.copyWith(
        clearAddress: true,
        clearContactNumber: true,
      );
      expect(cleared.address, isNull);
      expect(cleared.contactNumber, isNull);
      expect(cleared.name, 'Juan Dela Cruz');
    });

    test('equality is value-based via props', () {
      final same = MechanicEntity(
        id: 'mech-1',
        name: 'Juan Dela Cruz',
        isActive: true,
        address: '123 Rizal St, Cebu',
        contactNumber: '0917 123 4567',
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
