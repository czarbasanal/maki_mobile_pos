import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/config/router/route_guards.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  UserEntity user(UserRole role, {bool isActive = true}) => UserEntity(
        id: 'u1',
        email: 'u@x.com',
        displayName: 'U',
        role: role,
        isActive: isActive,
        createdAt: DateTime(2026, 7, 24),
      );

  group('RouteGuards — shared-list routes open to every active role', () {
    for (final role in UserRole.values) {
      test('$role can access the categories hub and a per-kind editor', () {
        expect(
          RouteGuards.canAccess(RoutePaths.categorySettings, user(role)),
          true,
        );
        expect(
          RouteGuards.canAccess(
              '${RoutePaths.categorySettings}/unit', user(role)),
          true,
        );
      });
    }

    test('inactive user is denied', () {
      expect(
        RouteGuards.canAccess(
            RoutePaths.categorySettings, user(UserRole.staff, isActive: false)),
        false,
      );
    });
  });

  group('RouteGuards — product categories editor is staff+admin only', () {
    test('cashier is blocked from /settings/categories/product', () {
      expect(
        RouteGuards.canAccess(
            '${RoutePaths.categorySettings}/product', user(UserRole.cashier)),
        isFalse,
      );
    });
    test('staff can access /settings/categories/product', () {
      expect(
        RouteGuards.canAccess(
            '${RoutePaths.categorySettings}/product', user(UserRole.staff)),
        isTrue,
      );
    });
    test('cashier still accesses other kind editors', () {
      expect(
        RouteGuards.canAccess(
            '${RoutePaths.categorySettings}/expense', user(UserRole.cashier)),
        isTrue,
      );
      expect(
        RouteGuards.canAccess(
            '${RoutePaths.categorySettings}/unit', user(UserRole.cashier)),
        isTrue,
      );
    });

    test(
        'unknown kind segment falls back to the product-editor gate '
        '(builder falls back to CategoryKind.product for unknown segments)',
        () {
      expect(
        RouteGuards.canAccess(
            '${RoutePaths.categorySettings}/bogus', user(UserRole.cashier)),
        isFalse,
      );
      expect(
        RouteGuards.canAccess(
            '${RoutePaths.categorySettings}/bogus', user(UserRole.staff)),
        isTrue,
      );
    });
  });

  group('RouteGuards — shop fees editor open to every active role', () {
    for (final role in UserRole.values) {
      test('$role can access the shop fees editor', () {
        expect(
          RouteGuards.canAccess(RoutePaths.shopFees, user(role)),
          true,
        );
      });
    }

    test('inactive user is denied', () {
      expect(
        RouteGuards.canAccess(
            RoutePaths.shopFees, user(UserRole.staff, isActive: false)),
        false,
      );
    });
  });
}
