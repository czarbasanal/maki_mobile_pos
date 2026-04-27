import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/providers/user_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/settings/settings_wdigets.dart';

/// Main settings screen with all configuration options.
///
/// All roles can access this screen to edit their display name and password.
/// Admin-only sections (user management, cost codes, logs) are conditionally shown.
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
          // ==================== PROFILE SECTION (ALL ROLES) ====================
          // All users can edit their display name and password
          _buildSectionHeader(context, 'My Profile'),
          _buildUserSection(context, ref, currentUser),

          const Divider(height: 1),

          // ==================== ADMIN SECTION (ADMIN ONLY) ====================
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

          // ==================== GENERAL SECTION (ALL ROLES) ====================
          _buildSectionHeader(context, 'General'),
          SettingsTile(
            icon: Icons.store,
            iconColor: Colors.teal,
            title: 'Store Information',
            subtitle: 'Business name and details',
            onTap: () {
              // TODO: Store info screen
            },
          ),
          SettingsTile(
            icon: Icons.info_outline,
            iconColor: Colors.grey,
            title: 'About',
            subtitle: 'App version ${AppConstants.appVersion}',
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      ),
    );
  }

  /// Builds the user profile section where all users can edit display name and password.
  Widget _buildUserSection(
      BuildContext context, WidgetRef ref, UserEntity? user) {
    if (user == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Current user info display
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _getRoleColor(user.role).withOpacity(0.2),
                child: Icon(
                  _getRoleIcon(user.role),
                  color: _getRoleColor(user.role),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getRoleColor(user.role).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user.role.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getRoleColor(user.role),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Edit display name
        SettingsTile(
          icon: Icons.person_outline,
          iconColor: Colors.blue,
          title: 'Display Name',
          subtitle: user.displayName,
          onTap: () => _showEditDisplayNameDialog(context, ref, user),
        ),

        // Change password
        SettingsTile(
          icon: Icons.lock_outline,
          iconColor: Colors.red,
          title: 'Change Password',
          subtitle: 'Update your login password',
          onTap: () => _showChangePasswordDialog(context, ref),
        ),
      ],
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.staff:
        return Colors.blue;
      case UserRole.cashier:
        return Colors.green;
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

  /// Shows dialog to edit display name.
  void _showEditDisplayNameDialog(
      BuildContext context, WidgetRef ref, UserEntity user) {
    final controller = TextEditingController(text: user.displayName);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            autofocus: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Display name is required';
              }
              if (value.trim().length < 2) {
                return 'Display name must be at least 2 characters';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final newName = controller.text.trim();
              if (newName == user.displayName) {
                Navigator.pop(dialogContext);
                return;
              }

              try {
                // Update the user's display name in Firestore
                final userOps = ref.read(userOperationsProvider.notifier);
                await userOps.updateUser(
                  user: user.copyWith(displayName: newName),
                  updatedBy: user.id,
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (context.mounted) {
                  context.showSuccessSnackBar('Display name updated');
                }
              } catch (e) {
                if (context.mounted) {
                  context.showErrorSnackBar('Failed to update: $e');
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Shows dialog to change password.
  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Current password is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'New password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value != newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setState(() => isLoading = true);

                      try {
                        final authActions = ref.read(authActionsProvider);
                        await authActions.updatePassword(
                          currentPassword: currentPasswordController.text,
                          newPassword: newPasswordController.text,
                        );

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (context.mounted) {
                          context.showSuccessSnackBar(
                              'Password changed successfully');
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (context.mounted) {
                          context.showErrorSnackBar(
                            e.toString().contains('wrong-password')
                                ? 'Current password is incorrect'
                                : 'Failed to change password: $e',
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: AppConstants.appVersion,
      applicationLegalese: '© ${DateTime.now().year} ${AppConstants.appName}',
    );
  }
}
