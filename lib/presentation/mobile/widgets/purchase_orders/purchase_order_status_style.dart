import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

/// Status color/icon language for purchase orders — draft = neutral,
/// ordered = amber (in flight), received = green, cancelled = red.
class PurchaseOrderStatusStyle {
  const PurchaseOrderStatusStyle({
    required this.icon,
    required this.textColor,
    required this.tint,
    required this.label,
  });

  final IconData icon;
  final Color textColor;
  final Color tint;
  final String label;

  static PurchaseOrderStatusStyle of(PurchaseOrderStatus status,
      {required bool dark}) {
    switch (status) {
      case PurchaseOrderStatus.draft:
        final c =
            dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
        return PurchaseOrderStatusStyle(
          icon: LucideIcons.pencilLine,
          textColor: c,
          tint: dark ? const Color(0x1FFFFFFF) : const Color(0x14000000),
          label: 'Draft',
        );
      case PurchaseOrderStatus.ordered:
        // Deep amber #C8881A in light has no token; gold-on-dark matches the
        // pending style used by the void queue.
        final c = dark ? AppColors.warningOnDark : const Color(0xFFC8881A);
        return PurchaseOrderStatusStyle(
          icon: LucideIcons.send,
          textColor: c,
          tint: dark ? const Color(0x24F5B547) : const Color(0x1FF57C00),
          label: 'Ordered',
        );
      case PurchaseOrderStatus.received:
        return PurchaseOrderStatusStyle(
          icon: LucideIcons.packageCheck,
          textColor: dark ? AppColors.successOnDark : AppColors.successDark,
          tint: dark ? const Color(0x294CAF50) : AppColors.successLight,
          label: 'Received',
        );
      case PurchaseOrderStatus.cancelled:
        final c = dark ? AppColors.errorOnDark : AppColors.error;
        return PurchaseOrderStatusStyle(
          icon: LucideIcons.ban,
          textColor: c,
          tint: dark ? const Color(0x24FF6B5E) : const Color(0x1AF44336),
          label: 'Cancelled',
        );
    }
  }
}
