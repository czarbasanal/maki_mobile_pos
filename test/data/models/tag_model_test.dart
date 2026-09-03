import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/models.dart';

void main() {
  group('TagModel', () {
    test('fromMap reads fields and defaults', () {
      final model = TagModel.fromMap(
        {
          'name': 'Intact',
          'color': 'green',
          'description': 'Physical count verified',
          'isActive': false,
          'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
          'createdBy': 'admin-1',
        },
        'tag-1',
      );
      expect(model.id, 'tag-1');
      expect(model.name, 'Intact');
      expect(model.color, 'green');
      expect(model.description, 'Physical count verified');
      expect(model.isActive, false);
      expect(model.createdAt, DateTime(2026, 9, 1));
      expect(model.updatedAt, isNull);
    });

    test('fromMap defaults missing name/color/isActive for legacy docs', () {
      final model = TagModel.fromMap(<String, dynamic>{}, 'tag-x');
      expect(model.name, '');
      expect(model.color, 'gray');
      expect(model.description, isNull);
      expect(model.isActive, true);
    });

    test('toMap emits name + color + description + isActive', () {
      final model = TagModel(
        id: 'tag-1',
        name: 'Intact',
        color: 'green',
        isActive: true,
        createdAt: DateTime(2026, 9, 1),
        createdBy: 'admin-1',
      );
      final map = model.toMap();
      expect(map['name'], 'Intact');
      expect(map['color'], 'green');
      expect(map.containsKey('description'), isTrue);
      expect(map['description'], isNull);
      expect(map['isActive'], true);
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('toCreateMap stamps server timestamps + createdBy', () {
      final model = TagModel(
        id: '',
        name: 'Intact',
        color: 'blue',
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
