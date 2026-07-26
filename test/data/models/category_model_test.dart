import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('CategoryEntity', () {
    late CategoryEntity category;

    setUp(() {
      category = CategoryEntity(
        id: 'cat-001',
        name: 'Milk Products',
        isActive: true,
        createdAt: DateTime(2025, 1, 1),
        code: '0007',
      );
    });

    test('should create a valid category entity', () {
      expect(category.id, 'cat-001');
      expect(category.name, 'Milk Products');
      expect(category.isActive, true);
      expect(category.code, '0007');
    });

    test('should create entity without code (null)', () {
      final noCategoryCode = CategoryEntity(
        id: 'cat-002',
        name: 'Beverages',
        isActive: true,
        createdAt: DateTime(2025, 1, 2),
      );
      expect(noCategoryCode.code, isNull);
    });

    test('copyWith should update code when provided', () {
      final updated = category.copyWith(code: '0008');
      expect(updated.code, '0008');
      expect(updated.name, category.name);
    });

    test('copyWith should preserve code when not provided', () {
      final updated = category.copyWith(name: 'New Name');
      expect(updated.code, '0007');
      expect(updated.name, 'New Name');
    });

    test('props should include code', () {
      expect(category.props, contains('0007'));
    });

    test('equality should consider code', () {
      final same = CategoryEntity(
        id: 'cat-001',
        name: 'Milk Products',
        isActive: true,
        createdAt: DateTime(2025, 1, 1),
        code: '0007',
      );
      expect(category, equals(same));

      final different = CategoryEntity(
        id: 'cat-001',
        name: 'Milk Products',
        isActive: true,
        createdAt: DateTime(2025, 1, 1),
        code: '0008',
      );
      expect(category, isNot(equals(different)));
    });
  });

  group('CategoryModel', () {
    late CategoryModel model;

    setUp(() {
      model = CategoryModel(
        id: 'cat-001',
        name: 'Milk Products',
        isActive: true,
        createdAt: DateTime(2025, 1, 1),
        code: '0007',
      );
    });

    test('should create category model with code', () {
      expect(model.id, 'cat-001');
      expect(model.name, 'Milk Products');
      expect(model.code, '0007');
    });

    test('should create category model without code', () {
      final noCode = CategoryModel(
        id: 'cat-002',
        name: 'Beverages',
        isActive: true,
        createdAt: DateTime(2025, 1, 2),
      );
      expect(noCode.code, isNull);
    });

    test('toEntity should convert to CategoryEntity with code', () {
      final entity = model.toEntity();
      expect(entity.id, model.id);
      expect(entity.name, model.name);
      expect(entity.code, model.code);
      expect(entity.code, '0007');
    });

    test('toEntity should convert to CategoryEntity without code', () {
      final noCode = CategoryModel(
        id: 'cat-002',
        name: 'Beverages',
        isActive: true,
        createdAt: DateTime(2025, 1, 2),
      );
      final entity = noCode.toEntity();
      expect(entity.code, isNull);
    });

    test('fromEntity should convert from CategoryEntity with code', () {
      final entity = model.toEntity();
      final fromEntity = CategoryModel.fromEntity(entity);
      expect(fromEntity.id, entity.id);
      expect(fromEntity.name, entity.name);
      expect(fromEntity.code, entity.code);
    });

    test('fromMap should include code when present', () {
      final map = {
        'name': 'Beverages',
        'isActive': true,
        'createdAt': DateTime.now(),
        'code': '0008',
      };
      final fromMap = CategoryModel.fromMap(map, 'cat-003');
      expect(fromMap.code, '0008');
    });

    test('fromMap should default code to null when missing', () {
      final map = {
        'name': 'Beverages',
        'isActive': true,
        'createdAt': DateTime.now(),
      };
      final fromMap = CategoryModel.fromMap(map, 'cat-003');
      expect(fromMap.code, isNull);
    });

    test('toCreateMap should include code when non-null', () {
      final createMap = model.toCreateMap('user-123');
      expect(createMap['code'], '0007');
    });

    test('toCreateMap should omit code when null', () {
      final noCode = CategoryModel(
        id: 'cat-002',
        name: 'Beverages',
        isActive: true,
        createdAt: DateTime(2025, 1, 2),
      );
      final createMap = noCode.toCreateMap('user-123');
      expect(createMap.containsKey('code'), isFalse);
    });

    test('toUpdateMap should not include code (codes are immutable)', () {
      final updateMap = model.toUpdateMap('user-456');
      expect(updateMap.containsKey('code'), isFalse);
    });

    test('toMap should include code when non-null', () {
      final map = model.toMap();
      expect(map['code'], '0007');
    });

    test('toMap should omit code when null', () {
      final noCode = CategoryModel(
        id: 'cat-002',
        name: 'Beverages',
        isActive: true,
        createdAt: DateTime(2025, 1, 2),
      );
      final map = noCode.toMap();
      expect(map.containsKey('code'), isFalse);
    });

    test('copyWith should update code', () {
      final updated = model.copyWith(code: '0009');
      expect(updated.code, '0009');
      expect(updated.name, model.name);
    });

    test('copyWith should preserve code when not provided', () {
      final updated = model.copyWith(name: 'New Name');
      expect(updated.code, '0007');
      expect(updated.name, 'New Name');
    });
  });
}
