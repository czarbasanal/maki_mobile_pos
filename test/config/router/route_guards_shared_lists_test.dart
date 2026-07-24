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
}
