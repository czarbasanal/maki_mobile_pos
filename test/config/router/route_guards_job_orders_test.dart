import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/config/router/route_guards.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
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

  test('job-order reports route is admin-only', () {
    expect(RoutePaths.jobOrderReports, '/reports/job-orders');
    expect(RouteNames.jobOrderReports, 'jobOrderReports');
    expect(
        RouteGuards.canAccess(
            RoutePaths.jobOrderReports, user(UserRole.admin)),
        isTrue);
    expect(
        RouteGuards.canAccess(
            RoutePaths.jobOrderReports, user(UserRole.cashier)),
        isFalse);
    expect(
        RouteGuards.canAccess(
            RoutePaths.jobOrderReports, user(UserRole.staff)),
        isFalse);
  });

  test('viewJobOrderReports is granted to admin only', () {
    expect(
        RolePermissions.hasPermission(
            UserRole.admin, Permission.viewJobOrderReports),
        isTrue);
    expect(
        RolePermissions.hasPermission(
            UserRole.cashier, Permission.viewJobOrderReports),
        isFalse);
    expect(
        RolePermissions.hasPermission(
            UserRole.staff, Permission.viewJobOrderReports),
        isFalse);
  });
}
