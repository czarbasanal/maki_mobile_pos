import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/widgets/settings/settings_wdigets.dart';

/// Main settings screen with all configuration options.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;
    final isAdmin = currentUser?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // User info section
          _buildUserSection(context, ref, currentUser),

          const Divider(height: 1),

          // Admin section
          if (isAdmin) ...[
            _buildSectionHeader(context, 'Administration'),
            SettingsTile(
              icon: Icons.people,
              iconColor: Colors.blue,
              title: 'User Management',
              subtitle: 'Add, edit, and manage users',
              onTap: () => context.push(RoutePaths.users),
            ),
            SettingsTile(
              icon: Icons.history,
              iconColor: Colors.purple,
              title: 'Activity Logs',
              subtitle: 'View user activity and audit trail',
              onTap: () => context.push(RoutePaths.userLogs),
            ),
            SettingsTile(
              icon: Icons.code,
              iconColor: Colors.orange,
              title: 'Cost Code Settings',
              subtitle: 'Configure cost encoding',
              onTap: () => context.push(RoutePaths.costCodeSettings),
            ),
            const Divider(height: 1),
          ],

          // General settings
          _buildSectionHeader(context, 'General'),
          SettingsTile(
            icon: Icons.store,
            iconColor: Colors.green,
            title: 'Business Information',
            subtitle: 'Store name, address, receipt details',
            onTap: () => _showComingSoon(context),
          ),
          SettingsTile(
            icon: Icons.receipt_long,
            iconColor: Colors.teal,
            title: 'Receipt Settings',
            subtitle: 'Header, footer, print options',
            onTap: () => _showComingSoon(context),
          ),
          SettingsTile(
            icon: Icons.attach_money,
            iconColor: Colors.amber,
            title: 'Tax Settings',
            subtitle: 'VAT configuration',
            onTap: () => _showComingSoon(context),
          ),

          const Divider(height: 1),

          // App section
          _buildSectionHeader(context, 'Application'),
          SettingsTile(
            icon: Icons.color_lens,
            iconColor: Colors.pink,
            title: 'Appearance',
            subtitle: 'Theme and display options',
            onTap: () => _showComingSoon(context),
          ),
          SettingsTile(
            icon: Icons.notifications,
            iconColor: Colors.red,
            title: 'Notifications',
            subtitle: 'Alert preferences',
            onTap: () => _showComingSoon(context),
          ),
          SettingsTile(
            icon: Icons.info_outline,
            iconColor: Colors.grey,
            title: 'About',
            subtitle: '${AppConstants.appName} v${AppConstants.appVersion}',
            onTap: () => context.push('${RoutePaths.settings}/about'),
          ),

          const Divider(height: 1),

          // Logout
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _handleLogout(context, ref),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildUserSection(
    BuildContext context,
    WidgetRef ref,
    dynamic currentUser,
  ) {
    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: _getRoleColor(currentUser.role).withOpacity(0.2),
            child: Icon(
              _getRoleIcon(currentUser.role),
              size: 30,
              color: _getRoleColor(currentUser.role),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentUser.displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  currentUser.email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor(currentUser.role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    currentUser.role.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getRoleColor(currentUser.role),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1,
        ),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.purple;
      case UserRole.staff:
        return Colors.green;
      case UserRole.cashier:
        return Colors.orange;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.staff:
        return Icons.badge;
      case UserRole.cashier:
        return Icons.point_of_sale;
    }
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coming soon!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authActionsProvider).signOut();
    }
  }
}
