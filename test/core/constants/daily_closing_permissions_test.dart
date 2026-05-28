import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';

void main() {
  group('End-of-day permissions', () {
    for (final role in UserRole.values) {
      test('${role.value} can view and close the day', () {
        expect(
            RolePermissions.hasPermission(role, Permission.viewEndOfDay), true);
        expect(RolePermissions.hasPermission(role, Permission.closeDay), true);
      });
    }
  });
}
