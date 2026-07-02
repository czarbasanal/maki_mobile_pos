import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/providers/draft_provider.dart';

/// POS app-bar button for Job Orders: a clipboard glyph with a count pill
/// showing the open job-order count (live, from the drafts stream).
///
/// The pill is primary-tinted (slate light / gold dark) with a 2px ring in
/// the app-bar surface color so it reads as "open job orders", not a stuck
/// cart count.
class JobOrderBadgeButton extends ConsumerWidget {
  final VoidCallback onPressed;

  const JobOrderBadgeButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final count = ref.watch(activeDraftCountProvider).valueOrNull ?? 0;
    final ring =
        theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;

    return IconButton(
      tooltip: 'Job Orders',
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(LucideIcons.clipboardList, size: 23),
          if (count > 0)
            Positioned(
              top: -6,
              right: -8,
              child: Container(
                constraints:
                    const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: ring, width: 2),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
