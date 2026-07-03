import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

/// Status color/icon language for purchase orders — draft = neutral,
/// ordered = amber (in flight), received = green, cancelled = red.
/// Labels come from [PurchaseOrderStatus.displayName], not from here.
class PurchaseOrderStatusStyle {
  const PurchaseOrderStatusStyle({
    required this.icon,
    required this.textColor,
    required this.tint,
  });

  final IconData icon;
  final Color textColor;
  final Color tint;

  static PurchaseOrderStatusStyle of(PurchaseOrderStatus status,
      {required bool dark}) {
    switch (status) {
      case PurchaseOrderStatus.draft:
        return PurchaseOrderStatusStyle(
          icon: LucideIcons.pencilLine,
          textColor: AppColors.poDraftFg(dark),
          tint: AppColors.poDraftBg(dark),
        );
      case PurchaseOrderStatus.ordered:
        return PurchaseOrderStatusStyle(
          icon: LucideIcons.send,
          textColor: AppColors.poOrderedFg(dark),
          tint: AppColors.poOrderedBg(dark),
        );
      case PurchaseOrderStatus.received:
        return PurchaseOrderStatusStyle(
          icon: LucideIcons.packageCheck,
          textColor: AppColors.poReceivedFg(dark),
          tint: AppColors.poReceivedBg(dark),
        );
      case PurchaseOrderStatus.cancelled:
        return PurchaseOrderStatusStyle(
          icon: LucideIcons.ban,
          textColor: AppColors.poCancelledFg(dark),
          tint: AppColors.poCancelledBg(dark),
        );
    }
  }
}
