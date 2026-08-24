// HR route gating — mirrors route_guards_mechanics_test. HR is a top-level
// Admin destination now (hub at /hr with Employees | Payroll | Payslips tabs,
// gear -> /hr/settings), all behind admin-only manageHr; the dynamic payslip
// detail is gated the same and unlisted /hr/* paths stay denied by the
// fail-safe default. The old /settings/hr/* homes are gone, not aliased.
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/config/router/route_guards.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

UserEntity _user(UserRole role) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  test('paths and names', () {
    expect(RoutePaths.hr, '/hr');
    expect(RoutePaths.hrPayslips, '/hr/payslips');
    expect(RoutePaths.hrSettings, '/hr/settings');
    expect(RouteNames.hrPayslipDetail, 'hrPayslipDetail');
  });

  test('static HR routes: admin yes, staff and cashier no', () {
    for (final path in [RoutePaths.hr, RoutePaths.hrSettings]) {
      expect(RouteGuards.canAccess(path, _user(UserRole.admin)), isTrue,
          reason: 'admin $path');
      expect(RouteGuards.canAccess(path, _user(UserRole.staff)), isFalse,
          reason: 'staff $path');
      expect(RouteGuards.canAccess(path, _user(UserRole.cashier)), isFalse,
          reason: 'cashier $path');
    }
  });

  test('dynamic payslip detail is gated the same', () {
    expect(
      RouteGuards.canAccess('/hr/payslips/abc123', _user(UserRole.admin)),
      isTrue,
    );
    expect(
      RouteGuards.canAccess('/hr/payslips/abc123', _user(UserRole.staff)),
      isFalse,
    );
  });

  test('an unlisted /hr/* path stays denied (fail-safe default)', () {
    expect(
      RouteGuards.canAccess('/hr/unknown', _user(UserRole.admin)),
      isFalse,
    );
  });

  test('the old /settings/hr/* homes are gone, not aliased', () {
    expect(
      RouteGuards.canAccess('/settings/hr/employees', _user(UserRole.admin)),
      isFalse,
    );
  });

  test('HR is a menu destination for admin only', () {
    expect(
      RouteGuards.getMenuItems(UserRole.admin).map((m) => m.path),
      contains(RoutePaths.hr),
    );
    for (final role in [UserRole.staff, UserRole.cashier]) {
      expect(
        RouteGuards.getMenuItems(role).map((m) => m.path),
        isNot(contains(RoutePaths.hr)),
        reason: role.value,
      );
    }
  });
}
