import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/constants/constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('UserEntity', () {
    late UserEntity testUser;

    setUp(() {
      testUser = UserEntity(
        id: 'test-id-123',
        email: 'test@example.com',
        displayName: 'Test User',
        role: UserRole.cashier,
        isActive: true,
        createdAt: DateTime(2025, 1, 1),
      );
    });

    test('should create a valid user entity', () {
      expect(testUser.id, 'test-id-123');
      expect(testUser.email, 'test@example.com');
      expect(testUser.displayName, 'Test User');
      expect(testUser.role, UserRole.cashier);
      expect(testUser.isActive, true);
    });

    test('cashier should have limited permissions', () {
      expect(testUser.hasPermission(Permission.accessPos), true);
      expect(testUser.hasPermission(Permission.viewInventory), false);
      expect(testUser.hasPermission(Permission.viewUsers), false);
    });

    test('inactive user should have no permissions', () {
      final inactiveUser = testUser.copyWith(isActive: false);
      expect(inactiveUser.hasPermission(Permission.accessPos), false);
    });

    test('admin should have all permissions', () {
      final adminUser = testUser.copyWith(role: UserRole.admin);
      expect(adminUser.hasPermission(Permission.accessPos), true);
      expect(adminUser.hasPermission(Permission.viewInventory), true);
      expect(adminUser.hasPermission(Permission.viewUsers), true);
      expect(adminUser.hasPermission(Permission.editCostCodeMapping), true);
    });

    test('staff should have intermediate permissions', () {
      final staffUser = testUser.copyWith(role: UserRole.staff);
      expect(staffUser.hasPermission(Permission.accessPos), true);
      expect(staffUser.hasPermission(Permission.viewInventory), true);
      expect(staffUser.hasPermission(Permission.viewProductCost), false);
      expect(staffUser.hasPermission(Permission.viewUsers), false);
    });

    test('role checks work correctly', () {
      expect(testUser.isCashier, true);
      expect(testUser.isStaff, false);
      expect(testUser.isAdmin, false);
      expect(testUser.isStaffOrAdmin, false);

      final staffUser = testUser.copyWith(role: UserRole.staff);
      expect(staffUser.isStaffOrAdmin, true);

      final adminUser = testUser.copyWith(role: UserRole.admin);
      expect(adminUser.isStaffOrAdmin, true);
    });

    test('copyWith creates new instance with updated values', () {
      final updatedUser = testUser.copyWith(
        displayName: 'Updated Name',
        role: UserRole.staff,
      );

      expect(updatedUser.id, testUser.id);
      expect(updatedUser.email, testUser.email);
      expect(updatedUser.displayName, 'Updated Name');
      expect(updatedUser.role, UserRole.staff);
    });

    test('entities with same properties are equal (Equatable)', () {
      final user1 = UserEntity(
        id: 'same-id',
        email: 'same@email.com',
        displayName: 'Same Name',
        role: UserRole.cashier,
        isActive: true,
        createdAt: DateTime(2025, 1, 1),
      );

      final user2 = UserEntity(
        id: 'same-id',
        email: 'same@email.com',
        displayName: 'Same Name',
        role: UserRole.cashier,
        isActive: true,
        createdAt: DateTime(2025, 1, 1),
      );

      expect(user1, user2);
    });
  });

  group('UserModel', () {
    late UserModel testModel;

    setUp(() {
      testModel = UserModel(
        id: 'test-id-123',
        email: 'test@example.com',
        displayName: 'Test User',
        role: UserRole.staff,
        isActive: true,
        phoneNumber: '+639171234567',
        createdAt: DateTime(2025, 1, 1),
      );
    });

    test('should create a valid user model', () {
      expect(testModel.id, 'test-id-123');
      expect(testModel.email, 'test@example.com');
      expect(testModel.role, UserRole.staff);
    });

    test('fromMap should parse data correctly', () {
      final map = {
        'email': 'map@example.com',
        'displayName': 'Map User',
        'role': 'admin',
        'isActive': true,
        'phoneNumber': '+639999999999',
        'createdAt': '2025-01-15T10:30:00.000Z',
      };

      final model = UserModel.fromMap(map, 'doc-id-456');

      expect(model.id, 'doc-id-456');
      expect(model.email, 'map@example.com');
      expect(model.displayName, 'Map User');
      expect(model.role, UserRole.admin);
      expect(model.isActive, true);
      expect(model.phoneNumber, '+639999999999');
    });

    test('toMap should serialize correctly', () {
      final map = testModel.toMap();

      expect(map['email'], 'test@example.com');
      expect(map['displayName'], 'Test User');
      expect(map['role'], 'staff');
      expect(map['isActive'], true);
      expect(map['phoneNumber'], '+639171234567');
      expect(map.containsKey('id'), false); // ID not included by default
    });

    test('toMap with includeId should include ID', () {
      final map = testModel.toMap(includeId: true);
      expect(map['id'], 'test-id-123');
    });

    test('toEntity should convert to domain entity', () {
      final entity = testModel.toEntity();

      expect(entity, isA<UserEntity>());
      expect(entity.id, testModel.id);
      expect(entity.email, testModel.email);
      expect(entity.displayName, testModel.displayName);
      expect(entity.role, testModel.role);
      expect(entity.isActive, testModel.isActive);
    });

    test('fromEntity should convert from domain entity', () {
      final entity = UserEntity(
        id: 'entity-id',
        email: 'entity@example.com',
        displayName: 'Entity User',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2025, 2, 1),
      );

      final model = UserModel.fromEntity(entity);

      expect(model.id, entity.id);
      expect(model.email, entity.email);
      expect(model.displayName, entity.displayName);
      expect(model.role, entity.role);
    });

    test('empty factory creates empty model', () {
      final empty = UserModel.empty();

      expect(empty.id, '');
      expect(empty.email, '');
      expect(empty.isActive, false);
      expect(empty.role, UserRole.cashier);
    });

    test('create factory creates model with defaults', () {
      final newUser = UserModel.create(
        id: 'new-id',
        email: 'new@example.com',
        displayName: 'New User',
        role: UserRole.cashier,
      );

      expect(newUser.id, 'new-id');
      expect(newUser.isActive, true);
      expect(newUser.createdAt, isNotNull);
    });

    test('fromMap handles missing optional fields', () {
      final minimalMap = {
        'email': 'minimal@example.com',
        'displayName': 'Minimal User',
      };

      final model = UserModel.fromMap(minimalMap, 'minimal-id');

      expect(model.id, 'minimal-id');
      expect(model.email, 'minimal@example.com');
      expect(model.role, UserRole.cashier); // Default role
      expect(model.isActive, true); // Default active
      expect(model.phoneNumber, isNull);
      expect(model.photoUrl, isNull);
    });

    test('fromMap handles invalid role gracefully', () {
      final mapWithInvalidRole = {
        'email': 'test@example.com',
        'displayName': 'Test',
        'role': 'invalid_role',
      };

      final model = UserModel.fromMap(mapWithInvalidRole, 'test-id');

      expect(model.role, UserRole.cashier); // Falls back to cashier
    });
  });
}
