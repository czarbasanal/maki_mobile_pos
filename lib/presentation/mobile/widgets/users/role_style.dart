import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// Color / icon / copy language for a [UserRole] — admin = red, staff = green,
/// cashier = orange, each with full dark-mode parity (bundle 12 handoff).
///
/// Single source of truth for the role avatar tint, role badge, and the role
/// picker rows. Mirrors the [VoidStatusStyle]/`PaymentMethodStyle` pattern and
/// replaces the `_getRoleColor`/`_getRoleIcon`/`_getRoleDescription` trios that
/// were duplicated across the user list tile, the user form, and `UserAvatar`.
class RoleStyle {
  const RoleStyle({
    required this.icon,
    required this.color,
    required this.badgeTextColor,
    required this.tileTint,
    required this.badgeBg,
    required this.badgeBorder,
    required this.label,
    required this.description,
  });

  /// Role glyph (avatar, badge, summary card, picker icon tile).
  final IconData icon;

  /// Primary role hue — icon + selected-state border/title.
  final Color color;

  /// Legible text color for the small role badge (deeper than [color] for the
  /// light-mode green/orange whose fill hue is too pale for 11px text).
  final Color badgeTextColor;

  /// Tinted fill for the round avatar and the picker icon tile.
  final Color tileTint;

  /// Role badge pill background.
  final Color badgeBg;

  /// Role badge pill border.
  final Color badgeBorder;

  /// Role name (matches [UserRole.displayName]).
  final String label;

  /// Fixed one-line role description shown in the form's role picker.
  final String description;

  static RoleStyle of(UserRole role, {required bool dark}) {
    switch (role) {
      case UserRole.admin:
        final c = dark ? AppColors.roleAdminOnDark : AppColors.roleAdmin;
        return RoleStyle(
          icon: LucideIcons.shieldHalf,
          color: c,
          badgeTextColor: c,
          tileTint: dark ? const Color(0x29F2756B) : const Color(0x1CD32F2F),
          badgeBg: dark ? const Color(0x29F2756B) : const Color(0x1AD32F2F),
          badgeBorder: dark ? const Color(0x57F2756B) : const Color(0x4DD32F2F),
          label: role.displayName,
          description: 'Full access to all features including user management',
        );
      case UserRole.staff:
        final c = dark ? AppColors.roleStaffOnDark : AppColors.roleStaff;
        return RoleStyle(
          icon: LucideIcons.tag,
          color: c,
          badgeTextColor: dark ? AppColors.roleStaffOnDark : AppColors.roleStaffText,
          tileTint: dark ? const Color(0x266FD47B) : const Color(0x244CAF50),
          badgeBg: dark ? const Color(0x246FD47B) : const Color(0x1F4CAF50),
          badgeBorder: dark ? const Color(0x526FD47B) : const Color(0x4D4CAF50),
          label: role.displayName,
          description: 'POS, inventory, and receiving (no cost visibility)',
        );
      case UserRole.cashier:
        final c = dark ? AppColors.roleCashierOnDark : AppColors.roleCashier;
        return RoleStyle(
          icon: LucideIcons.shoppingCart,
          color: c,
          badgeTextColor:
              dark ? AppColors.roleCashierOnDark : AppColors.roleCashierText,
          tileTint: dark ? const Color(0x26F5B547) : const Color(0x24FF9800),
          badgeBg: dark ? const Color(0x24F5B547) : const Color(0x21FF9800),
          badgeBorder: dark ? const Color(0x52F5B547) : const Color(0x57FF9800),
          label: role.displayName,
          description: 'POS operations only',
        );
    }
  }
}
