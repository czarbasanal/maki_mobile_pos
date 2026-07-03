import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/purchase_orders/purchase_order_status_style.dart';

/// The one status pill both the list card and the detail header render — a
/// tinted rounded chip with the status glyph and [PurchaseOrderStatus.displayName].
class PurchaseOrderStatusPill extends StatelessWidget {
  const PurchaseOrderStatusPill({super.key, required this.status});

  final PurchaseOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final style = PurchaseOrderStatusStyle.of(status, dark: dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.tint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 12, color: style.textColor),
          const SizedBox(width: 4),
          Text(status.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: style.textColor,
              )),
        ],
      ),
    );
  }
}
