import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// Card displaying a summary metric on the dashboard.
///
/// Pass [iconColor] only when the value carries a status meaning
/// (success/warning/error). For neutral metrics, leave it null and the
/// card falls back to the theme's muted variant — the value is the
/// hero, not the icon.
class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final String? subtitle;
  final bool compact;
  final bool highlighted;
  final VoidCallback? onTap;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.subtitle,
    this.compact = false,
    this.highlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (compact) {
      return _buildCompactCard(theme);
    }
    return _buildFullCard(theme);
  }

  Widget _buildFullCard(ThemeData theme) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final accent = iconColor ?? muted;
    return Card(
      shape: highlighted
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: BorderSide(color: accent, width: 1.5),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: accent, size: 20),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      CupertinoIcons.chevron_right,
                      color: muted,
                      size: 16,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCard(ThemeData theme) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final accent = iconColor ?? muted;
    return Card(
      shape: highlighted
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: accent, width: 1.5),
            )
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(
                color: theme.brightness == Brightness.dark
                    ? AppColors.darkHairline
                    : AppColors.lightHairline,
              ),
            ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm + 4,
          ),
          child: Column(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: highlighted ? accent : null,
                ),
              ),
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: muted,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
