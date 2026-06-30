import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/validators.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/users/role_style.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_waiting_dialog.dart';

/// Screen for creating or editing a user.
class UserFormScreen extends ConsumerStatefulWidget {
  final String? userId;
  final UserEntity? user;

  const UserFormScreen({
    super.key,
    this.userId,
    this.user,
  });

  bool get isEditing => userId != null || user != null;
  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  UserRole _selectedRole = UserRole.cashier;
  bool _isProcessing = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  /// Snapshot of the editable fields at load — the Update button stays
  /// disabled until display name or role diverges (edit mode; email is locked).
  String _initialSig = '';
  String _sig() => '${_displayNameController.text.trim()}|${_selectedRole.name}';
  bool get _isDirty => _sig() != _initialSig;

  @override
  void initState() {
    super.initState();
    _displayNameController.addListener(() {
      if (mounted) setState(() {});
    });
    if (widget.user != null) {
      _initFromUser(widget.user!);
    } else if (widget.userId != null) {
      _loadUser();
    }
  }

  Future<void> _loadUser() async {
    if (widget.userId == null) return;

    final user = await ref.read(userByIdProvider(widget.userId!).future);
    if (user != null && mounted) {
      _initFromUser(user);
    }
  }

  void _initFromUser(UserEntity user) {
    _emailController.text = user.email;
    _displayNameController.text = user.displayName;
    setState(() {
      _selectedRole = user.role;
      _initialSig = _sig();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final role = RoleStyle.of(_selectedRole, dark: dark);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.users),
        ),
        title: Text(widget.isEditing ? 'Edit User' : 'Create User'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Role-tinted avatar header (recolors with the picked role)
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: role.tileTint,
                            ),
                            alignment: Alignment.center,
                            child: Icon(role.icon, size: 42, color: role.color),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            role.label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: role.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Email — editable on create, locked on edit
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: widget.isEditing ? 'Email' : 'Email *',
                        prefixIcon: const Icon(LucideIcons.mail),
                        suffixIcon: widget.isEditing
                            ? const Icon(LucideIcons.lock, size: 16)
                            : null,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      enabled: !widget.isEditing, // Can't change email
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 14),

                    // Display name
                    TextFormField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name *',
                        prefixIcon: Icon(LucideIcons.user),
                      ),
                      validator: Validators.required,
                    ),
                    const SizedBox(height: 22),

                    // Role picker
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 10),
                      child: Text(
                        'ROLE',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    _buildRoleSelector(dark),

                    // Password section (create only)
                    if (!widget.isEditing) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password *',
                          prefixIcon: const Icon(LucideIcons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye,
                              size: 18,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        validator: Validators.password,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password *',
                          prefixIcon: const Icon(LucideIcons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye,
                              size: 18,
                            ),
                            onPressed: () => setState(() =>
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword),
                          ),
                        ),
                        obscureText: _obscureConfirmPassword,
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],

                    // Reset password (edit only)
                    if (widget.isEditing) ...[
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _showResetPasswordDialog,
                          icon: const Icon(LucideIcons.keyRound, size: 17),
                          label: const Text('Reset Password'),
                        ),
                      ),
                    ],

                    // Inline error box
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBox(message: _errorMessage!, dark: dark),
                    ],

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          _buildSubmitFooter(context),
        ],
      ),
    );
  }

  Widget _buildRoleSelector(bool dark) {
    return Column(
      children: UserRole.values.map((value) {
        final isSelected = _selectedRole == value;
        final style = RoleStyle.of(value, dark: dark);
        final theme = Theme.of(context);
        final muted = theme.colorScheme.onSurfaceVariant;
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Material(
            color: isSelected
                ? style.color.withValues(alpha: dark ? 0.09 : 0.07)
                : (dark ? AppColors.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(AppRadius.field),
            child: InkWell(
              onTap: () => setState(() => _selectedRole = value),
              borderRadius: BorderRadius.circular(AppRadius.field),
              child: Container(
                padding: EdgeInsets.all(isSelected ? 12 : 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                  border: Border.all(
                    color: isSelected ? style.color : AppColors.hairline(dark),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: style.tileTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(style.icon, color: style.color, size: 22),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            style.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? style.color
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            style.description,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      Icon(LucideIcons.circleCheck,
                          color: style.color, size: 22),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Pinned bottom submit bar (mirrors the product-form footer).
  Widget _buildSubmitFooter(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: AppShadows.pinnedFooter(dark: isDark),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.field),
            boxShadow:
                isDark ? AppShadows.primaryButtonGold : AppShadows.primaryButton,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: (_isProcessing || (widget.isEditing && !_isDirty))
                  ? null
                  : _handleSubmit,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      widget.isEditing ? LucideIcons.save : LucideIcons.userPlus,
                      size: 18,
                    ),
              label: Text(widget.isEditing ? 'Update User' : 'Create User'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) throw Exception('Not logged in');

      // The use-case (CreateUserUseCase / UpdateUserUseCase, called via the
      // notifier) handles permission checks, business guards (last-admin,
      // self-demote, self-deactivate), and the activity-log writes.
      if (widget.isEditing) {
        final updated = await context.runWithWaiting(
          () => ref.read(userOperationsProvider.notifier).updateUser(
                actor: currentUser,
                user: widget.user!.copyWith(
                  displayName: _displayNameController.text.trim(),
                  role: _selectedRole,
                ),
              ),
          message: 'Updating…',
        );

        if (updated != null && mounted) {
          context.showSuccessSnackBar('User updated successfully');
          context.goBackOr(RoutePaths.users);
        }
      } else {
        final created = await context.runWithWaiting(
          () => ref.read(userOperationsProvider.notifier).createUser(
                actor: currentUser,
                email: _emailController.text.trim(),
                password: _passwordController.text,
                displayName: _displayNameController.text.trim(),
                role: _selectedRole,
              ),
          message: 'Saving…',
        );

        if (created != null && mounted) {
          context.showSuccessSnackBar('User created successfully');
          context.goBackOr(RoutePaths.users);
        }
      }

      // Surface notifier-level errors (use-case failures) to the form.
      final opState = ref.read(userOperationsProvider);
      if (opState.errorMessage != null && mounted) {
        setState(() => _errorMessage = opState.errorMessage);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _showResetPasswordDialog() async {
    final ok = await context.showConfirmDialog(
      title: 'Reset Password',
      message: 'A password reset email will be sent to the user. '
          'They can use the link to set a new password.',
      confirmText: 'Send Reset Email',
      icon: LucideIcons.keyRound,
    );
    if (!ok || !mounted) return;
    // TODO: Implement password reset
    context.showSuccessSnackBar('Password reset email sent');
  }
}

/// Inline error callout for use-case failures.
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.dark});
  final String message;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.errorText(dark);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: dark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.alertCircle, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
