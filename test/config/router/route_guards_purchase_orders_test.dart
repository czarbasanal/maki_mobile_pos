import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/config/router/route_guards.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
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

  test('paths and names', () {
    expect(RoutePaths.purchaseOrders, '/reorder');
    expect(RoutePaths.purchaseOrderNew, '/reorder/new');
    expect(RouteNames.purchaseOrders, 'purchaseOrders');
    expect(RouteNames.purchaseOrderNew, 'purchaseOrderNew');
    expect(RouteNames.purchaseOrderDetail, 'purchaseOrderDetail');
  });

  test('list route: staff and admin yes, cashier no', () {
    for (final role in [UserRole.admin, UserRole.staff]) {
      expect(RouteGuards.canAccess(RoutePaths.purchaseOrders, user(role)),
          isTrue,
          reason: '$role');
    }
    expect(
        RouteGuards.canAccess(RoutePaths.purchaseOrders, user(UserRole.cashier)),
        isFalse);
  });

  test('dynamic child routes are gated the same', () {
    expect(
        RouteGuards.canAccess(RoutePaths.purchaseOrderNew, user(UserRole.staff)),
        isTrue);
    expect(RouteGuards.canAccess('/reorder/abc123', user(UserRole.staff)),
        isTrue);
    expect(RouteGuards.canAccess('/reorder/abc123', user(UserRole.cashier)),
        isFalse);
  });

  test('Reorder menu item sits after Inventory for staff/admin only', () {
    for (final role in [UserRole.staff, UserRole.admin]) {
      final paths =
          RouteGuards.getMenuItems(role).map((e) => e.path).toList();
      expect(paths, contains(RoutePaths.purchaseOrders), reason: '$role');
      expect(paths.indexOf(RoutePaths.purchaseOrders),
          paths.indexOf(RoutePaths.inventory) + 1,
          reason: 'Reorder directly follows Inventory');
    }
    expect(
        RouteGuards.getMenuItems(UserRole.cashier)
            .map((e) => e.path)
            .toList(),
        isNot(contains(RoutePaths.purchaseOrders)));
  });
}
