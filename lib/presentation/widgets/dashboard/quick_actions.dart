import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// Quick action buttons for the dashboard.
class QuickActions extends StatelessWidget {
  final VoidCallback onNewSale;
  final VoidCallback? onReceiving;
  final VoidCallback? onInventory;
  final VoidCallback? onReports;

  const QuickActions({
    super.key,
    required this.onNewSale,
    this.onReceiving,
    this.onInventory,
    this.onReports,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickActionButton(
            icon: Icons.add_shopping_cart,
            label: 'New Sale',
            color: AppColors.primaryAccent,
            onTap: onNewSale,
          ),
          if (onReceiving != null)
            _QuickActionButton(
              icon: Icons.inventory,
              label: 'Receive Stock',
              color: Colors.green,
              onTap: onReceiving!,
            ),
          if (onInventory != null)
            _QuickActionButton(
              icon: Icons.inventory_2,
              label: 'Inventory',
              color: Colors.orange,
              onTap: onInventory!,
            ),
          if (onReports != null)
            _QuickActionButton(
              icon: Icons.analytics,
              label: 'Reports',
              color: Colors.purple,
              onTap: onReports!,
            ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
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
