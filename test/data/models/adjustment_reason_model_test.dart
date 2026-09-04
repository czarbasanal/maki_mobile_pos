import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/models.dart';

void main() {
  group('AdjustmentReasonModel', () {
    test('fromMap reads fields and defaults', () {
      final model = AdjustmentReasonModel.fromMap(
        {
          'name': 'Inventory Loss',
          'requiresNote': true,
          'isActive': false,
          'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
          'createdBy': 'admin-1',
        },
        'reason-1',
      );
      expect(model.id, 'reason-1');
      expect(model.name, 'Inventory Loss');
      expect(model.requiresNote, true);
      expect(model.isActive, false);
      expect(model.createdAt, DateTime(2026, 9, 1));
      expect(model.updatedAt, isNull);
    });

    test('fromMap defaults missing name/requiresNote/isActive for legacy docs', () {
      final model = AdjustmentReasonModel.fromMap(<String, dynamic>{}, 'reason-x');
      expect(model.name, '');
      expect(model.requiresNote, false);
      expect(model.isActive, true);
    });

    test('toMap emits name + requiresNote + isActive', () {
      final model = AdjustmentReasonModel(
        id: 'reason-1',
        name: 'Inventory Loss',
        requiresNote: true,
        isActive: true,
        createdAt: DateTime(2026, 9, 1),
        createdBy: 'admin-1',
      );
      final map = model.toMap();
      expect(map['name'], 'Inventory Loss');
      expect(map['requiresNote'], true);
      expect(map['isActive'], true);
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('toCreateMap stamps server timestamps + createdBy', () {
      final model = AdjustmentReasonModel(
        id: '',
        name: 'Inventory Loss',
        requiresNote: false,
        isActive: true,
        createdAt: DateTime(2026, 9, 1),
      );
      final map = model.toCreateMap('admin-9');
      expect(map['createdBy'], 'admin-9');
      expect(map['updatedBy'], 'admin-9');
      expect(map['createdAt'], isA<FieldValue>());
      expect(map['updatedAt'], isA<FieldValue>());
    });
  });
}
