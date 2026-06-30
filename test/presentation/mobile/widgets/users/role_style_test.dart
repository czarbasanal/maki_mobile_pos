import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/users/role_style.dart';

void main() {
  group('RoleStyle.of', () {
    test('maps each role to its Lucide icon', () {
      expect(RoleStyle.of(UserRole.admin, dark: false).icon,
          LucideIcons.shieldHalf);
      expect(RoleStyle.of(UserRole.staff, dark: false).icon, LucideIcons.tag);
      expect(RoleStyle.of(UserRole.cashier, dark: false).icon,
          LucideIcons.shoppingCart);
    });

    test('label matches the role displayName', () {
      for (final role in UserRole.values) {
        expect(RoleStyle.of(role, dark: false).label, role.displayName);
      }
    });

    test('descriptions are the fixed per-role copy', () {
      expect(RoleStyle.of(UserRole.cashier, dark: false).description,
          'POS operations only');
      expect(RoleStyle.of(UserRole.staff, dark: false).description,
          'POS, inventory, and receiving (no cost visibility)');
      expect(RoleStyle.of(UserRole.admin, dark: false).description,
          'Full access to all features including user management');
    });

    test('the three role colors are distinct', () {
      final admin = RoleStyle.of(UserRole.admin, dark: false).color;
      final staff = RoleStyle.of(UserRole.staff, dark: false).color;
      final cashier = RoleStyle.of(UserRole.cashier, dark: false).color;
      expect(admin, isNot(staff));
      expect(staff, isNot(cashier));
      expect(admin, isNot(cashier));
    });

    test('dark variant differs from light for every role', () {
      for (final role in UserRole.values) {
        expect(
          RoleStyle.of(role, dark: true).color,
          isNot(RoleStyle.of(role, dark: false).color),
          reason: 'dark color should differ from light for $role',
        );
      }
    });

    test('admin is red, staff is green, cashier is orange (light)', () {
      expect(RoleStyle.of(UserRole.admin, dark: false).color,
          const Color(0xFFD32F2F));
      expect(RoleStyle.of(UserRole.staff, dark: false).color,
          const Color(0xFF3E9E44));
      expect(RoleStyle.of(UserRole.cashier, dark: false).color,
          const Color(0xFFD17A00));
    });
  });
}
