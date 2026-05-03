import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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

  const QuickActions({
    super.key,
    required this.onNewSale,
    this.onReceiving,
    this.onInventory,
    this.onExpenses,
    this.onReports,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickActionButton(
            icon: CupertinoIcons.cart_badge_plus,
            label: 'New Sale',
            isPrimary: true,
            onTap: onNewSale,
          ),
          if (onReceiving != null)
            _QuickActionButton(
              icon: CupertinoIcons.square_arrow_down,
              label: 'Receive Stock',
              onTap: onReceiving!,
            ),
          if (onInventory != null)
            _QuickActionButton(
              icon: CupertinoIcons.cube_box,
              label: 'Inventory',
              onTap: onInventory!,
            ),
          if (onExpenses != null)
            _QuickActionButton(
              icon: CupertinoIcons.doc_text,
              label: 'Expenses',
              onTap: onExpenses!,
            ),
          if (onReports != null)
            _QuickActionButton(
              icon: CupertinoIcons.chart_bar,
              label: 'Reports',
              onTap: onReports!,
            ),
        ],
      ),
    );
  }
}

/// Outlined pill button for the dashboard's quick-actions row.
///
/// All actions share the same neutral treatment so the row reads as a
/// quiet menu of options. The single primary action gets a filled
/// treatment in the brand slate to anchor the row.
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;

    final fg = isPrimary
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    final bg = isPrimary ? theme.colorScheme.primary : Colors.transparent;
    final border = isPrimary ? theme.colorScheme.primary : hairline;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm + 4),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: border),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md + 4,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(icon, color: fg, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
