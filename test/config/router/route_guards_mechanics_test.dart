import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/config/router/route_guards.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  UserEntity user(UserRole role) => UserEntity(
        id: 'u1',
        email: 'u@x.com',
        displayName: 'U',
        role: role,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      );

  group('RouteGuards — mechanics', () {
    test('path constant is /settings/mechanics', () {
      expect(RoutePaths.mechanics, '/settings/mechanics');
      expect(RouteNames.mechanics, 'mechanics');
    });

    test('admin can access mechanics editor', () {
      expect(
        RouteGuards.canAccess(RoutePaths.mechanics, user(UserRole.admin)),
        true,
      );
    });

    test('cashier and staff can access mechanics editor (editLists)', () {
      expect(
        RouteGuards.canAccess(RoutePaths.mechanics, user(UserRole.cashier)),
        true,
      );
      expect(
        RouteGuards.canAccess(RoutePaths.mechanics, user(UserRole.staff)),
        true,
      );
    });
  });
}
