import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
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
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          if (currentUser != null) ...[
            const _SectionHeader('My Profile'),
            _SectionCard(
              children: [
                _ProfileHero(user: currentUser),
                SettingsTile(
                  icon: CupertinoIcons.person,
                  title: 'Display Name',
                  subtitle: currentUser.displayName,
                  onTap: () =>
                      _showEditDisplayNameDialog(context, ref, currentUser),
                ),
                SettingsTile(
                  icon: CupertinoIcons.lock,
                  title: 'Change Password',
                  subtitle: 'Update your login password',
                  onTap: () => _showChangePasswordDialog(context, ref),
                ),
              ],
            ),
          ],
          if (isAdmin) ...[
            const _SectionHeader('Administration'),
            _SectionCard(
              children: [
                SettingsTile(
                  icon: CupertinoIcons.person_2,
                  title: 'User Management',
                  subtitle: 'Add, edit, and manage users',
                  onTap: () => context.push(RoutePaths.users),
                ),
                SettingsTile(
                  icon: CupertinoIcons.clock,
                  title: 'Activity Logs',
                  subtitle: 'View user activity and audit trail',
                  onTap: () => context.push(RoutePaths.userLogs),
                ),
                SettingsTile(
                  icon: CupertinoIcons.chevron_left_slash_chevron_right,
                  title: 'Cost Code Settings',
                  subtitle: 'Configure cost encoding',
                  onTap: () => context.push(RoutePaths.costCodeSettings),
                ),
                SettingsTile(
                  icon: CupertinoIcons.tag,
                  title: 'Manage Lists',
                  subtitle: 'Product / expense categories and units',
                  onTap: () => context.push(RoutePaths.categorySettings),
                ),
              ],
            ),
          ],
          const _SectionHeader('General'),
          _SectionCard(
            children: [
              _buildThemeTile(context, ref),
              SettingsTile(
                icon: Icons.store_outlined,
                title: 'Store Information',
                subtitle: 'Business name and details',
                onTap: () {
                  // TODO: Store info screen
                },
              ),
              SettingsTile(
                icon: CupertinoIcons.info_circle,
                title: 'About',
                subtitle: 'App version ${AppConstants.appVersion}',
                onTap: () => _showAboutDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
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
              prefixIcon: Icon(CupertinoIcons.person),
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
                // Update the user's display name in Firestore.
                // The user is editing themselves (editOwnProfile path); the
                // use-case enforces editUser permission and skips role-change
                // / last-admin guards because the role isn't changing.
                final userOps = ref.read(userOperationsProvider.notifier);
                await userOps.updateUser(
                  actor: user,
                  user: user.copyWith(displayName: newName),
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
                    prefixIcon: Icon(CupertinoIcons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Current password is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: newPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(CupertinoIcons.lock),
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
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(CupertinoIcons.lock),
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

  Widget _buildThemeTile(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final (label, icon) = switch (mode) {
      ThemeMode.system => ('System', CupertinoIcons.brightness),
      ThemeMode.light => ('Light', CupertinoIcons.sun_max),
      ThemeMode.dark => ('Dark', CupertinoIcons.moon),
    };
    return SettingsTile(
      icon: icon,
      title: 'Theme',
      subtitle: label,
      onTap: () => _showThemePicker(context, ref),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final current = ref.read(themeModeProvider);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in const [
                (ThemeMode.system, 'System default', CupertinoIcons.brightness),
                (ThemeMode.light, 'Light', CupertinoIcons.sun_max),
                (ThemeMode.dark, 'Dark', CupertinoIcons.moon),
              ])
                RadioListTile<ThemeMode>(
                  value: entry.$1,
                  groupValue: current,
                  title: Text(entry.$2),
                  secondary: Icon(entry.$3),
                  onChanged: (mode) {
                    if (mode == null) return;
                    ref.read(themeModeProvider.notifier).set(mode);
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        );
      },
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

// ==================== LAYOUT PRIMITIVES ====================

/// Small uppercase header that introduces a section card.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md + AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Rounded card grouping a list of rows separated by hairline dividers.
///
/// Hairlines are indented past the icon column so the divider lines up
/// under the row text — the classic iOS-settings rhythm.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: _withDividers(children),
        ),
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> items) {
    if (items.length <= 1) return items;
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        out.add(const Divider(
          height: 1,
          indent: AppSpacing.md + 22 + AppSpacing.md, // align under title
        ));
      }
      out.add(items[i]);
    }
    return out;
  }
}

/// Profile hero block — avatar, name, email, role pill — sits at the top
/// of the profile section card.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user});

  final UserEntity user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleColor = _roleColor(user.role);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: roleColor.withOpacity(0.08),
            child: Icon(
              _roleIcon(user.role),
              color: roleColor,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    user.role.displayName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: roleColor,
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

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.staff:
        return Colors.blue;
      case UserRole.cashier:
        return Colors.green;
    }
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return CupertinoIcons.shield_lefthalf_fill;
      case UserRole.staff:
        return CupertinoIcons.tag;
      case UserRole.cashier:
        return CupertinoIcons.cart;
    }
  }
}
