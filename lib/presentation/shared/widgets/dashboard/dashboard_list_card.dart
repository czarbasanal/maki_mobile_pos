import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// Elevated container for dashboard list sections (Top Selling, Recent).
///
/// Light: white surface lifted with a soft [AppShadows.card]. Dark: card
/// surface with a 1px hairline border (the dark theme leans on borders, not
/// shadows). Clips children so row dividers and ripples follow the rounded
/// corners.
class DashboardListCard extends StatelessWidget {
  final Widget child;

  const DashboardListCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border:
            isDark ? Border.all(color: AppColors.darkHairline) : null,
        boxShadow: AppShadows.card(dark: isDark),
      ),
      child: child,
    );
  }
}
