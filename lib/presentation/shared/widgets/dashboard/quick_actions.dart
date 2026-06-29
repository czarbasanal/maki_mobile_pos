import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// Quick action buttons for the dashboard.
///
/// Updated to include Expenses and use role-based visibility:
/// - New Sale: all roles
/// - Receive Stock: staff + admin
/// - Inventory: all roles
/// - Expenses: all roles
/// - Reports: all roles
class QuickActions extends StatelessWidget {
  final VoidCallback onNewSale;
  final VoidCallback? onReceiving;
  final VoidCallback? onInventory;
  final VoidCallback? onExpenses;
  final VoidCallback? onReports;
  final VoidCallback? onCloseDay;

  const QuickActions({
    super.key,
    required this.onNewSale,
    this.onReceiving,
    this.onInventory,
    this.onExpenses,
    this.onReports,
    this.onCloseDay,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickActionButton(
            icon: LucideIcons.shoppingCart,
            label: 'New Sale',
            isPrimary: true,
            onTap: onNewSale,
          ),
          if (onReceiving != null)
            _QuickActionButton(
              icon: LucideIcons.download,
              label: 'Receive Stock',
              onTap: onReceiving!,
            ),
          if (onInventory != null)
            _QuickActionButton(
              icon: LucideIcons.package,
              label: 'Inventory',
              onTap: onInventory!,
            ),
          if (onExpenses != null)
            _QuickActionButton(
              icon: LucideIcons.receipt,
              label: 'Expenses',
              onTap: onExpenses!,
            ),
          if (onReports != null)
            _QuickActionButton(
              icon: LucideIcons.barChart3,
              label: 'Reports',
              onTap: onReports!,
            ),
          if (onCloseDay != null)
            _QuickActionButton(
              icon: LucideIcons.calendarX,
              label: 'Close Day',
              isDestructive: true,
              onTap: onCloseDay!,
            ),
        ],
      ),
    );
  }
}

/// A single quick-action pill (50px tall, radius 16).
///
/// The row reads as a quiet menu: outlined pills with a hairline border and a
/// muted icon. The one **primary** action (New Sale) is filled in the brand
/// slate (gold in dark) with an elevated [AppShadows.newSalePill] glow to
/// anchor the row. Close Day is error-outlined.
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final bool isDestructive;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hairline = isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final errorColor = isDark ? const Color(0xFFFF6B5E) : AppColors.error;

    final Color bg;
    final Color border;
    final Color textColor;
    final Color iconColor;
    if (isDestructive) {
      bg = scheme.surface;
      border = errorColor;
      textColor = errorColor;
      iconColor = errorColor;
    } else if (isPrimary) {
      bg = scheme.primary;
      border = scheme.primary;
      textColor = scheme.onPrimary;
      iconColor = scheme.onPrimary;
    } else {
      bg = scheme.surface;
      border = hairline;
      textColor = scheme.onSurface;
      iconColor = scheme.onSurfaceVariant;
    }

    final radius = BorderRadius.circular(AppRadius.field);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: isPrimary ? AppShadows.newSalePill(dark: isDark) : null,
        ),
        child: Material(
          color: bg,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
