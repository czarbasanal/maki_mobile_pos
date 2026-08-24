// HR route gating — mirrors route_guards_mechanics_test. manageHr is
// admin-only, so every /settings/hr/* path (including the dynamic payslip
// detail) admits admins and turns everyone else away; an unlisted
// /settings/hr/* path stays denied by the fail-safe default.
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
    expect(RoutePaths.hrEmployees, '/settings/hr/employees');
    expect(RoutePaths.hrPayroll, '/settings/hr/payroll');
    expect(RoutePaths.hrPayslips, '/settings/hr/payslips');
    expect(RoutePaths.hrSettings, '/settings/hr/settings');
    expect(RouteNames.hrPayslipDetail, 'hrPayslipDetail');
  });

  test('static HR routes: admin yes, staff and cashier no', () {
    for (final path in [
      RoutePaths.hrEmployees,
      RoutePaths.hrPayroll,
      RoutePaths.hrPayslips,
      RoutePaths.hrSettings,
    ]) {
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
      RouteGuards.canAccess(
          '/settings/hr/payslips/abc123', _user(UserRole.admin)),
      isTrue,
    );
    expect(
      RouteGuards.canAccess(
          '/settings/hr/payslips/abc123', _user(UserRole.staff)),
      isFalse,
    );
  });

  test('an unlisted /settings/hr/* path stays denied (fail-safe default)', () {
    expect(
      RouteGuards.canAccess('/settings/hr/unknown', _user(UserRole.admin)),
      isFalse,
    );
  });
}
