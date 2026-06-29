import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/settings/settings_wdigets.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';

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
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          if (currentUser != null) ...[
            const _SectionHeader('My Profile', isFirst: true),
            _SectionCard(
              heroFirst: true,
              children: [
                _ProfileHero(user: currentUser),
                SettingsTile(
                  icon: LucideIcons.user,
                  title: 'Display Name',
                  subtitle: currentUser.displayName,
                  onTap: () =>
                      _showEditDisplayNameDialog(context, ref, currentUser),
                ),
                SettingsTile(
                  icon: LucideIcons.lock,
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
                  icon: LucideIcons.users,
                  title: 'User Management',
                  subtitle: 'Add, edit, and manage users',
                  onTap: () => context.push(RoutePaths.users),
                ),
                SettingsTile(
                  icon: LucideIcons.clock,
                  title: 'Activity Logs',
                  subtitle: 'View user activity and audit trail',
                  onTap: () => context.push(RoutePaths.userLogs),
                ),
                SettingsTile(
                  icon: LucideIcons.code,
                  title: 'Cost Code Settings',
                  subtitle: 'Configure cost encoding',
                  onTap: () => context.push(RoutePaths.costCodeSettings),
                ),
                SettingsTile(
                  icon: LucideIcons.tag,
                  title: 'Manage Lists',
                  subtitle: 'Product / expense categories and units',
                  onTap: () => context.push(RoutePaths.categorySettings),
                ),
                SettingsTile(
                  icon: LucideIcons.wrench,
                  title: 'Mechanics',
                  subtitle: 'Assign a mechanic to a service draft',
                  onTap: () => context.push(RoutePaths.mechanics),
                ),
              ],
            ),
          ],
          const _SectionHeader('General'),
          _SectionCard(
            children: [
              _buildThemeTile(context, ref),
              SettingsTile(
                icon: LucideIcons.store,
                title: 'Store Information',
                subtitle: 'Business name and details',
                onTap: () {
                  // TODO: Store info screen
                },
              ),
              SettingsTile(
                icon: LucideIcons.info,
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
              prefixIcon: Icon(LucideIcons.user),
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
                    prefixIcon: Icon(LucideIcons.lock),
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
                    prefixIcon: Icon(LucideIcons.lock),
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
                    prefixIcon: Icon(LucideIcons.lock),
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
    // Subtitle reflects the selected mode; the glyph is `sun` everywhere except
    // Dark, which shows `moon` (per the 10a spec — the hub row uses sun/moon
    // only, while the picker rows use monitor/sun/moon).
    final (label, icon) = switch (mode) {
      ThemeMode.system => ('System', LucideIcons.sun),
      ThemeMode.light => ('Light', LucideIcons.sun),
      ThemeMode.dark => ('Dark', LucideIcons.moon),
    };
    return SettingsTile(
      icon: icon,
      title: 'Theme',
      subtitle: label,
      onTap: () => _showThemePicker(context, ref),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    final current = ref.read(themeModeProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final dark = theme.brightness == Brightness.dark;
        final sheetBg = dark ? AppColors.darkCard : Colors.white;
        final hairline =
            dark ? AppColors.darkHairline : const Color(0xFFF0F0F0);
        final handleColor =
            dark ? AppColors.darkHairline : const Color(0xFFD8D5CF);
        final primary = theme.colorScheme.primary;

        Widget radioRow(
            ThemeMode mode, String label, IconData icon, bool selected) {
          return InkWell(
            onTap: () {
              ref.read(themeModeProvider.notifier).set(mode);
              Navigator.pop(sheetContext);
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 21,
                    color: selected ? primary : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  // Radio indicator
                  selected
                      ? Container(
                          width: 21,
                          height: 21,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: primary, width: 2),
                          ),
                          child: Center(
                            child: Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primary,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          width: 21,
                          height: 21,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(color: Color(0xFFC2C8CA), width: 2),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grab handle
                Container(
                  margin: const EdgeInsets.only(top: 11, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Theme',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                radioRow(ThemeMode.system, 'System default',
                    LucideIcons.monitor, current == ThemeMode.system),
                Container(
                    height: 1,
                    color: hairline,
                    margin: const EdgeInsets.only(left: 55)),
                radioRow(ThemeMode.light, 'Light', LucideIcons.sun,
                    current == ThemeMode.light),
                Container(
                    height: 1,
                    color: hairline,
                    margin: const EdgeInsets.only(left: 55)),
                radioRow(ThemeMode.dark, 'Dark', LucideIcons.moon,
                    current == ThemeMode.dark),
              ],
            ),
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
  const _SectionHeader(this.title, {this.isFirst = false});

  final String title;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(18, isFirst ? 16 : 18, 18, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Rounded AppCard grouping a list of rows separated by hairline dividers.
///
/// When [heroFirst] is true, the first divider (between the profile hero and
/// the first tile) is inset 16px on both sides. All other dividers are
/// left-indented at 62px (past the icon tile).
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children, this.heroFirst = false});

  final List<Widget> children;
  final bool heroFirst;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hairline =
        dark ? AppColors.darkHairline : const Color(0xFFF0F0F0);

    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: _withDividers(children, hairline),
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> items, Color hairline) {
    if (items.length <= 1) return items;
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        final isHeroDivider = heroFirst && i == 1;
        out.add(
          isHeroDivider
              ? Container(
                  height: 1,
                  color: hairline,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                )
              : Container(
                  height: 1,
                  color: hairline,
                  margin: const EdgeInsets.only(left: 62),
                ),
        );
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
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final roleColor = _roleColor(user.role, dark);
    final avatarBg = roleColor.withValues(alpha: dark ? 0.22 : 0.10);
    final pillBg = roleColor.withValues(alpha: dark ? 0.22 : 0.10);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: avatarBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _roleIcon(user.role),
              color: roleColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: TextStyle(fontSize: 12.5, color: muted),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    user.role.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
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

  Color _roleColor(UserRole role, bool dark) {
    switch (role) {
      case UserRole.admin:
        return dark ? const Color(0xFFFF6B5E) : const Color(0xFFF44336);
      case UserRole.staff:
        return dark ? const Color(0xFF7FB8F5) : const Color(0xFF2196F3);
      case UserRole.cashier:
        return dark ? const Color(0xFF8FE39A) : const Color(0xFF4CAF50);
    }
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return LucideIcons.shieldHalf;
      case UserRole.staff:
      case UserRole.cashier:
        return LucideIcons.userRound;
    }
  }
}
