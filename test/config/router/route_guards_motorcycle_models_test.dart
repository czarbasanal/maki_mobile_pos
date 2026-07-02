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
        createdAt: DateTime(2026, 7, 1),
      );

  group('RouteGuards — motorcycle models', () {
    test('path + name constants', () {
      expect(RoutePaths.motorcycleModels, '/settings/motorcycle-models');
      expect(RouteNames.motorcycleModels, 'motorcycleModels');
    });

    test('admin can access the editor', () {
      expect(
        RouteGuards.canAccess(RoutePaths.motorcycleModels, user(UserRole.admin)),
        true,
      );
    });

    test('cashier cannot access the editor', () {
      expect(
        RouteGuards.canAccess(
            RoutePaths.motorcycleModels, user(UserRole.cashier)),
        false,
      );
    });
  });
}
