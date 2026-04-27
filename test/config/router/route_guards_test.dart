import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/config/router/route_guards.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';

UserEntity _user(UserRole role, {bool isActive = true}) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: isActive,
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  group('RouteGuards.isPublicRoute', () {
    test('login is public', () {
      expect(RouteGuards.isPublicRoute(RoutePaths.login), true);
    });

    test('any authenticated path is not public', () {
      expect(RouteGuards.isPublicRoute(RoutePaths.dashboard), false);
      expect(RouteGuards.isPublicRoute(RoutePaths.pos), false);
      expect(RouteGuards.isPublicRoute(RoutePaths.users), false);
    });
  });

  group('RouteGuards.canAccess — unauthenticated', () {
    test('null user can access /login', () {
      expect(RouteGuards.canAccess(RoutePaths.login, null), true);
    });

    test('null user cannot access any protected route', () {
      expect(RouteGuards.canAccess(RoutePaths.dashboard, null), false);
      expect(RouteGuards.canAccess(RoutePaths.pos, null), false);
      expect(RouteGuards.canAccess(RoutePaths.inventory, null), false);
      expect(RouteGuards.canAccess(RoutePaths.users, null), false);
    });
  });

  group('RouteGuards.canAccess — inactive user', () {
    test('inactive admin is denied every protected route', () {
      final inactive = _user(UserRole.admin, isActive: false);
      expect(RouteGuards.canAccess(RoutePaths.dashboard, inactive), false);
      expect(RouteGuards.canAccess(RoutePaths.pos, inactive), false);
      expect(RouteGuards.canAccess(RoutePaths.inventory, inactive), false);
      expect(RouteGuards.canAccess(RoutePaths.users, inactive), false);
    });

    test('inactive user can still access /login (public)', () {
      final inactive = _user(UserRole.cashier, isActive: false);
      expect(RouteGuards.canAccess(RoutePaths.login, inactive), true);
    });
  });

  // The matrix: row = role, columns = routes. Entries are the expected
  // canAccess() outcome. Common routes (POS, drafts, dashboard) should be true
  // for every role; admin-only routes should be true only for admin.
  group('RouteGuards.canAccess — role × route matrix', () {
    final cashier = _user(UserRole.cashier);
    final staff = _user(UserRole.staff);
    final admin = _user(UserRole.admin);

    final matrix = <String, _Expected>{
      RoutePaths.dashboard:
          const _Expected(cashier: true, staff: true, admin: true),
      RoutePaths.pos: const _Expected(cashier: true, staff: true, admin: true),
      RoutePaths.checkout:
          const _Expected(cashier: true, staff: true, admin: true),
      RoutePaths.drafts:
          const _Expected(cashier: true, staff: true, admin: true),
      RoutePaths.inventory:
          const _Expected(cashier: true, staff: true, admin: true),
      RoutePaths.productAdd:
          const _Expected(cashier: false, staff: false, admin: true),
      RoutePaths.receiving:
          const _Expected(cashier: false, staff: true, admin: true),
      RoutePaths.bulkReceiving:
          const _Expected(cashier: false, staff: true, admin: true),
      RoutePaths.suppliers:
          const _Expected(cashier: false, staff: false, admin: true),
      RoutePaths.supplierAdd:
          const _Expected(cashier: false, staff: false, admin: true),
      RoutePaths.expenses:
          const _Expected(cashier: true, staff: true, admin: true),
      RoutePaths.expenseAdd:
          const _Expected(cashier: true, staff: true, admin: true),
      RoutePaths.reports:
          const _Expected(cashier: true, staff: true, admin: true),
      RoutePaths.salesReport:
          const _Expected(cashier: true, staff: true, admin: true),
      RoutePaths.profitReport:
          const _Expected(cashier: false, staff: false, admin: true),
      RoutePaths.users:
          const _Expected(cashier: false, staff: false, admin: true),
      RoutePaths.userAdd:
          const _Expected(cashier: false, staff: false, admin: true),
      RoutePaths.settings:
          const _Expected(cashier: true, staff: true, admin: true),
      RoutePaths.costCodeSettings:
          const _Expected(cashier: false, staff: false, admin: true),
      RoutePaths.userLogs:
          const _Expected(cashier: false, staff: false, admin: true),
      RoutePaths.pettyCash:
          const _Expected(cashier: false, staff: false, admin: true),
      RoutePaths.pettyCashNew:
          const _Expected(cashier: false, staff: false, admin: true),
    };

    matrix.forEach((path, expected) {
      test('$path  cashier=${expected.cashier}, staff=${expected.staff}, admin=${expected.admin}',
          () {
        expect(RouteGuards.canAccess(path, cashier), expected.cashier,
            reason: 'cashier should ${expected.cashier ? "" : "not "}access $path');
        expect(RouteGuards.canAccess(path, staff), expected.staff,
            reason: 'staff should ${expected.staff ? "" : "not "}access $path');
        expect(RouteGuards.canAccess(path, admin), expected.admin,
            reason: 'admin should ${expected.admin ? "" : "not "}access $path');
      });
    });
  });

  group('RouteGuards.canAccess — dynamic routes', () {
    test('inventory edit allows staff (limited) and admin (full)', () {
      expect(
          RouteGuards.canAccess(
              '/inventory/edit/abc123', _user(UserRole.staff)),
          true);
      expect(
          RouteGuards.canAccess(
              '/inventory/edit/abc123', _user(UserRole.admin)),
          true);
    });

    test('inventory edit denies cashier (no edit permission)', () {
      expect(
          RouteGuards.canAccess(
              '/inventory/edit/abc123', _user(UserRole.cashier)),
          false);
    });

    test('expense edit denies cashier and staff (admin-only)', () {
      expect(
          RouteGuards.canAccess(
              '/expenses/edit/exp-1', _user(UserRole.cashier)),
          false);
      expect(
          RouteGuards.canAccess(
              '/expenses/edit/exp-1', _user(UserRole.staff)),
          false);
      expect(
          RouteGuards.canAccess(
              '/expenses/edit/exp-1', _user(UserRole.admin)),
          true);
    });

    test('user edit is admin-only', () {
      expect(
          RouteGuards.canAccess(
              '/users/edit/u-1', _user(UserRole.cashier)),
          false);
      expect(
          RouteGuards.canAccess(
              '/users/edit/u-1', _user(UserRole.staff)),
          false);
      expect(RouteGuards.canAccess('/users/edit/u-1', _user(UserRole.admin)),
          true);
    });

    test('supplier edit is admin-only', () {
      expect(
          RouteGuards.canAccess(
              '/suppliers/edit/s-1', _user(UserRole.staff)),
          false);
      expect(
          RouteGuards.canAccess(
              '/suppliers/edit/s-1', _user(UserRole.admin)),
          true);
    });

    test('inventory detail (view) is allowed for any role with viewInventory',
        () {
      expect(
          RouteGuards.canAccess('/inventory/p-1', _user(UserRole.cashier)),
          true);
      expect(RouteGuards.canAccess('/inventory/p-1', _user(UserRole.staff)),
          true);
      expect(RouteGuards.canAccess('/inventory/p-1', _user(UserRole.admin)),
          true);
    });

    test('draft edit (e.g. /drafts/abc) is treated as common route', () {
      expect(RouteGuards.canAccess('/drafts/abc', _user(UserRole.cashier)),
          true);
      expect(RouteGuards.canAccess('/drafts/abc', _user(UserRole.staff)),
          true);
      expect(RouteGuards.canAccess('/drafts/abc', _user(UserRole.admin)),
          true);
    });
  });

  group('RouteGuards.getMenuItems', () {
    test('cashier sees POS, Drafts, Inventory, Expenses, Reports, Settings',
        () {
      final paths = RouteGuards.getMenuItems(UserRole.cashier)
          .map((e) => e.path)
          .toSet();
      expect(paths, contains(RoutePaths.pos));
      expect(paths, contains(RoutePaths.drafts));
      expect(paths, contains(RoutePaths.inventory));
      expect(paths, contains(RoutePaths.expenses));
      expect(paths, contains(RoutePaths.reports));
      expect(paths, contains(RoutePaths.settings));
      expect(paths, isNot(contains(RoutePaths.receiving)));
      expect(paths, isNot(contains(RoutePaths.suppliers)));
      expect(paths, isNot(contains(RoutePaths.users)));
      expect(paths, isNot(contains(RoutePaths.pettyCash)));
      expect(paths, isNot(contains(RoutePaths.userLogs)));
    });

    test('staff additionally sees Receiving', () {
      final paths = RouteGuards.getMenuItems(UserRole.staff)
          .map((e) => e.path)
          .toSet();
      expect(paths, contains(RoutePaths.receiving));
      expect(paths, isNot(contains(RoutePaths.suppliers)));
      expect(paths, isNot(contains(RoutePaths.users)));
      expect(paths, isNot(contains(RoutePaths.pettyCash)));
      expect(paths, isNot(contains(RoutePaths.userLogs)));
    });

    test('admin sees the full menu including Suppliers, Users, Logs, Petty Cash',
        () {
      final paths = RouteGuards.getMenuItems(UserRole.admin)
          .map((e) => e.path)
          .toSet();
      expect(paths, contains(RoutePaths.suppliers));
      expect(paths, contains(RoutePaths.users));
      expect(paths, contains(RoutePaths.userLogs));
      expect(paths, contains(RoutePaths.pettyCash));
    });
  });
}

class _Expected {
  final bool cashier;
  final bool staff;
  final bool admin;
  const _Expected({
    required this.cashier,
    required this.staff,
    required this.admin,
  });
}
