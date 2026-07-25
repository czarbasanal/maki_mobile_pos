import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/unsettled_day_provider.dart';

/// Warning banner surfaced wherever a new sale could be started (POS,
/// dashboard) while an earlier business day is still unsettled — mirrors
/// [ReportsWarningBanner]'s amber look (shared `AppColors.warningBanner*`
/// tokens), plus a trailing `Close Day` button that routes straight to the
/// End-of-Day screen for that date.
///
/// Renders nothing while [unsettledBusinessDayProvider] is null, loading, or
/// errored — a self-contained widget, no plumbing required at call sites.
class UnsettledDrawerBanner extends ConsumerWidget {
  const UnsettledDrawerBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unsettled = ref.watch(unsettledBusinessDayProvider).valueOrNull;
    if (unsettled == null) return const SizedBox.shrink();

    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.warningBannerFill(dark);
    final border = AppColors.warningBannerBorder(dark);
    final textColor = AppColors.warningBannerText(dark);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.alertTriangle,
            size: 19,
            color: AppColors.warningIcon(dark),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              "The drawer for ${DateFormat('MMM d').format(unsettled)} "
              "hasn't been closed. Close it before new sales.",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () =>
                context.pushNamed(RouteNames.endOfDay, extra: unsettled),
            style: TextButton.styleFrom(
              foregroundColor: textColor,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text(
              'Close Day',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
