import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';

void main() {
  group('RolePermissions — editProductNameOnly', () {
    test('cashier has editProductNameOnly', () {
      expect(
        RolePermissions.hasPermission(
            UserRole.cashier, Permission.editProductNameOnly),
        isTrue,
      );
    });

    test('staff does not have editProductNameOnly', () {
      expect(
        RolePermissions.hasPermission(
            UserRole.staff, Permission.editProductNameOnly),
        isFalse,
      );
    });

    test('admin does not have editProductNameOnly', () {
      expect(
        RolePermissions.hasPermission(
            UserRole.admin, Permission.editProductNameOnly),
        isFalse,
      );
    });

    test('canEditProductNameOnly is true only for cashier', () {
      expect(RolePermissions.canEditProductNameOnly(UserRole.cashier), isTrue);
      expect(RolePermissions.canEditProductNameOnly(UserRole.staff), isFalse);
      expect(RolePermissions.canEditProductNameOnly(UserRole.admin), isFalse);
    });
  });

  group('RolePermissions — requestVoidSale', () {
    test('cashier and staff have requestVoidSale; admin does not', () {
      expect(RolePermissions.hasPermission(
          UserRole.cashier, Permission.requestVoidSale), isTrue);
      expect(RolePermissions.hasPermission(
          UserRole.staff, Permission.requestVoidSale), isTrue);
      expect(RolePermissions.hasPermission(
          UserRole.admin, Permission.requestVoidSale), isFalse);
    });

    test('voidSale stays admin-only', () {
      expect(RolePermissions.hasPermission(
          UserRole.cashier, Permission.voidSale), isFalse);
      expect(RolePermissions.hasPermission(
          UserRole.staff, Permission.voidSale), isFalse);
      expect(RolePermissions.hasPermission(
          UserRole.admin, Permission.voidSale), isTrue);
    });
  });

  group('RolePermissions — addProduct', () {
    test('cashier does NOT have addProduct', () {
      expect(
        RolePermissions.hasPermission(UserRole.cashier, Permission.addProduct),
        isFalse,
      );
    });

    test('staff HAS addProduct', () {
      expect(
        RolePermissions.hasPermission(UserRole.staff, Permission.addProduct),
        isTrue,
      );
    });

    test('admin HAS addProduct', () {
      expect(
        RolePermissions.hasPermission(UserRole.admin, Permission.addProduct),
        isTrue,
      );
    });
  });

  group('RolePermissions — shared lists (editLists / manageCategories)', () {
    test('all roles hold editLists', () {
      for (final role in UserRole.values) {
        expect(
          RolePermissions.hasPermission(role, Permission.editLists),
          isTrue,
          reason: '$role should hold editLists',
        );
      }
    });

    test('staff and admin hold manageCategories; cashier does not', () {
      expect(
        RolePermissions.hasPermission(
            UserRole.cashier, Permission.manageCategories),
        isFalse,
      );
      expect(
        RolePermissions.hasPermission(
            UserRole.staff, Permission.manageCategories),
        isTrue,
      );
      expect(
        RolePermissions.hasPermission(
            UserRole.admin, Permission.manageCategories),
        isTrue,
      );
    });
  });
}
