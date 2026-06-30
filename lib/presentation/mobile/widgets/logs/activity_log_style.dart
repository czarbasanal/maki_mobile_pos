import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';

/// Icon + color language for an [ActivityType] in the audit feed (bundle 13).
///
/// Color is reserved for audit-meaningful events only — `isSecurityRelated`
/// → error red, `isFinancialAction` → success green, everything else neutral
/// slate (matching the entity getters, not the broader prototype red). The
/// glyph is a semantic per-type Lucide icon. Mirrors `RoleStyle`.
class ActivityLogStyle {
  const ActivityLogStyle({
    required this.icon,
    required this.iconColor,
    required this.tileFill,
  });

  /// Semantic per-action glyph for the 38×38 leading tile.
  final IconData icon;

  /// Glyph color (category-driven).
  final Color iconColor;

  /// Tinted fill behind the glyph.
  final Color tileFill;

  static ActivityLogStyle of(ActivityType type, {required bool dark}) {
    final icon = iconFor(type);
    if (type.isFinancialAction) {
      return ActivityLogStyle(
        icon: icon,
        iconColor: dark ? AppColors.successOnDarkIcon : AppColors.successDark,
        tileFill: dark
            ? AppColors.success.withValues(alpha: 0.16)
            : AppColors.successLight,
      );
    }
    if (type.isSecurityRelated) {
      return ActivityLogStyle(
        icon: icon,
        iconColor: dark ? AppColors.errorOnDark : const Color(0xFFE5392B),
        tileFill: dark
            ? AppColors.errorOnDark.withValues(alpha: 0.14)
            : AppColors.error.withValues(alpha: 0.10),
      );
    }
    // Neutral — the icon carries the categorical hint, color is reserved.
    return ActivityLogStyle(
      icon: icon,
      iconColor: dark ? const Color(0xFF9FB0B0) : AppColors.brandSlate,
      tileFill: dark
          ? const Color(0x0FFFFFFF)
          : AppColors.brandSlate.withValues(alpha: 0.07),
    );
  }

  /// Semantic Lucide glyph per activity type (all 24).
  static IconData iconFor(ActivityType type) {
    switch (type) {
      case ActivityType.authentication:
        return LucideIcons.shield;
      case ActivityType.login:
        return LucideIcons.logIn;
      case ActivityType.logout:
        return LucideIcons.logOut;
      case ActivityType.sale:
        return LucideIcons.shoppingCart;
      case ActivityType.voidSale:
        return LucideIcons.ban;
      case ActivityType.refund:
        return LucideIcons.undo2;
      case ActivityType.inventory:
        return LucideIcons.package;
      case ActivityType.stockAdjustment:
        return LucideIcons.slidersHorizontal;
      case ActivityType.receiving:
        return LucideIcons.download;
      case ActivityType.userManagement:
        return LucideIcons.users;
      case ActivityType.userCreated:
        return LucideIcons.userPlus;
      case ActivityType.userUpdated:
        return LucideIcons.userPen;
      case ActivityType.userDeactivated:
        return LucideIcons.userX;
      case ActivityType.roleChanged:
        return LucideIcons.userCog;
      case ActivityType.security:
        return LucideIcons.shieldAlert;
      case ActivityType.passwordVerified:
        return LucideIcons.shieldCheck;
      case ActivityType.passwordFailed:
        return LucideIcons.shieldX;
      case ActivityType.costViewed:
        return LucideIcons.eye;
      case ActivityType.settings:
        return LucideIcons.settings;
      case ActivityType.costCodeChanged:
        return LucideIcons.hash;
      case ActivityType.expense:
        return LucideIcons.receipt;
      case ActivityType.supplier:
        return LucideIcons.truck;
      case ActivityType.dayClosed:
        return LucideIcons.notebookPen;
      case ActivityType.other:
        return LucideIcons.fileText;
    }
  }
}
