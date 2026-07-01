import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('MechanicModel', () {
    test('fromMap reads fields and defaults', () {
      final model = MechanicModel.fromMap(
        {
          'name': 'Juan Dela Cruz',
          'isActive': false,
          'address': '123 Rizal St, Cebu',
          'contactNumber': '0917 123 4567',
          'createdAt': Timestamp.fromDate(DateTime(2026, 5, 30)),
          'createdBy': 'admin-1',
        },
        'mech-1',
      );
      expect(model.id, 'mech-1');
      expect(model.name, 'Juan Dela Cruz');
      expect(model.isActive, false);
      expect(model.address, '123 Rizal St, Cebu');
      expect(model.contactNumber, '0917 123 4567');
      expect(model.createdAt, DateTime(2026, 5, 30));
      expect(model.createdBy, 'admin-1');
      expect(model.updatedAt, isNull);
    });

    test('fromMap defaults missing name/isActive for legacy docs', () {
      final model = MechanicModel.fromMap(<String, dynamic>{}, 'mech-x');
      expect(model.name, '');
      expect(model.isActive, true);
      expect(model.address, isNull);
      expect(model.contactNumber, isNull);
    });

    test('toMap (plain) emits name + isActive + address + contact', () {
      final model = MechanicModel(
        id: 'mech-1',
        name: 'Pedro',
        isActive: true,
        address: '456 Mabini St',
        contactNumber: '0999 000 1111',
        createdAt: DateTime(2026, 5, 30),
        createdBy: 'admin-1',
      );
      final map = model.toMap();
      expect(map['name'], 'Pedro');
      expect(map['isActive'], true);
      expect(map['address'], '456 Mabini St');
      expect(map['contactNumber'], '0999 000 1111');
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['createdBy'], 'admin-1');
    });

    test('toMap emits null address/contact when unset (clears the field)', () {
      final model = MechanicModel(
        id: 'mech-1',
        name: 'Pedro',
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      );
      final map = model.toMap();
      expect(map.containsKey('address'), isTrue);
      expect(map['address'], isNull);
      expect(map['contactNumber'], isNull);
    });

    test('toCreateMap stamps server timestamps + createdBy', () {
      final model = MechanicModel(
        id: '',
        name: 'Pedro',
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      );
      final map = model.toCreateMap('admin-9');
      expect(map['createdBy'], 'admin-9');
      expect(map['updatedBy'], 'admin-9');
      expect(map['createdAt'], isA<FieldValue>());
    });

    test('round-trips entity <-> model', () {
      final entity = MechanicEntity(
        id: 'mech-1',
        name: 'Juan',
        isActive: true,
        address: '123 Rizal St, Cebu',
        contactNumber: '0917 123 4567',
        createdAt: DateTime(2026, 5, 30),
        createdBy: 'admin-1',
      );
      final back = MechanicModel.fromEntity(entity).toEntity();
      expect(back, equals(entity));
    });
  });
}
