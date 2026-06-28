import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// Soft-amber notice shown to daily-reports-only roles in place of the
/// date-range picker. Used by both Sales History (two-line, alert-triangle)
/// and Sales Report (single-line, lock). The amber palette is centralized in
/// [AppColors.warningBanner*] (shared with the End-of-Day post-close banner).
class ReportsWarningBanner extends StatelessWidget {
  const ReportsWarningBanner({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.warningBannerFill(dark);
    final border = AppColors.warningBannerBorder(dark);
    final titleColor = AppColors.warningBannerText(dark);
    final subColor =
        dark ? AppColors.warningOnDark : const Color(0xFFA07A2E);

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
          Icon(icon, size: 19, color: AppColors.warningIcon(dark)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 11.5, color: subColor),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
