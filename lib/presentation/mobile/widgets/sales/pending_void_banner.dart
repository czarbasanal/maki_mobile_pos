import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// "Void pending approval" banner on a sale that has an open void request.
///
/// Pass [onTap] (admins) to make the whole card tap through to the
/// void-requests queue — a chevron marks it as navigable. Without [onTap]
/// (cashier/staff, who can only wait) it stays a static status card.
class PendingVoidBanner extends StatelessWidget {
  const PendingVoidBanner({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final banner = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.clock, size: 18),
          const SizedBox(width: 8),
          const Text('Void pending approval'),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(LucideIcons.chevronRight, size: 16),
          ],
        ],
      ),
    );

    if (onTap == null) return banner;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: banner,
    );
  }
}
