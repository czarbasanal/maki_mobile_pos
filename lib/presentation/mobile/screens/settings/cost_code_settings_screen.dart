import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/password_dialog.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/settings/cost_code_editor.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Screen for viewing and editing cost code mapping.
class CostCodeSettingsScreen extends ConsumerStatefulWidget {
  const CostCodeSettingsScreen({super.key});

  @override
  ConsumerState<CostCodeSettingsScreen> createState() =>
      _CostCodeSettingsScreenState();
}

class _CostCodeSettingsScreenState
    extends ConsumerState<CostCodeSettingsScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  CostCodeEntity? _editedMapping;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mappingAsync = ref.watch(costCodeMappingProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('Cost Code Settings'),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _cancelEditing,
              child: const Text('Cancel'),
            )
          else
            IconButton(
              icon: const Icon(CupertinoIcons.pencil),
              tooltip: 'Edit mapping',
              onPressed: () => _startEditing(mappingAsync.value),
            ),
        ],
      ),
      body: mappingAsync.when(
        data: (mapping) => _buildContent(theme, mapping),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      bottomNavigationBar: _isEditing ? _buildBottomBar(theme) : null,
    );
  }

  Widget _buildContent(ThemeData theme, CostCodeEntity mapping) {
    final displayMapping = _editedMapping ?? mapping;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card
          _buildInfoCard(theme),

          const SizedBox(height: 24),

          // Current mapping section
          Text(
            'Digit to Letter Mapping',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Each digit (0-9) is encoded as a letter to hide costs.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 16),

          // Mapping editor/display
          if (_isEditing)
            CostCodeEditor(
              mapping: displayMapping,
              onMappingChanged: (updated) {
                setState(() => _editedMapping = updated);
              },
            )
          else
            _buildMappingDisplay(theme, displayMapping),

          const SizedBox(height: 24),

          // Special codes section
          Text(
            'Special Codes',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildSpecialCodesCard(theme, displayMapping),

          const SizedBox(height: 24),

          // Test section
          _buildTestSection(theme, displayMapping),

          const SizedBox(height: 24),

          // Reset to default button (only when not editing)
          if (!_isEditing)
            Center(
              child: OutlinedButton.icon(
                onPressed: () => _resetToDefault(mapping),
                icon: const Icon(CupertinoIcons.arrow_counterclockwise),
                label: const Text('Reset to Default'),
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              CupertinoIcons.info_circle,
              color: theme.colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About Cost Codes',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cost codes hide actual product costs from unauthorized users. '
                    'Only admins can view or modify this mapping.',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMappingDisplay(ThemeData theme, CostCodeEntity mapping) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final mutedFill =
        isDark ? AppColors.darkSurfaceMuted : AppColors.lightSurfaceMuted;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Digit',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: muted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Icon(CupertinoIcons.forward, size: 14, color: muted),
                Expanded(
                  child: Text(
                    'Code',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: muted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            // Mapping rows
            ...List.generate(10, (index) {
              final digit = index.toString();
              final letter = mapping.digitToLetter[digit] ?? '?';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: mutedFill,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: hairline),
                        ),
                        child: Text(
                          digit,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Icon(
                        CupertinoIcons.forward,
                        size: 16,
                        color: muted,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: theme.colorScheme.primary,
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: theme.colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialCodesCard(ThemeData theme, CostCodeEntity mapping) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSpecialCodeRow(
              theme,
              '00',
              mapping.doubleZeroCode,
              'Double Zero',
            ),
            const Divider(),
            _buildSpecialCodeRow(
              theme,
              '000',
              mapping.tripleZeroCode,
              'Triple Zero',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialCodeRow(
    ThemeData theme,
    String digits,
    String code,
    String label,
  ) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final mutedFill =
        isDark ? AppColors.darkSurfaceMuted : AppColors.lightSurfaceMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 4,
              vertical: AppSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: mutedFill,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: hairline),
            ),
            child: Text(
              digits,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Icon(CupertinoIcons.forward, color: muted, size: 14),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 4,
              vertical: AppSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: theme.colorScheme.primary,
                width: 1.2,
              ),
            ),
            child: Text(
              code,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const Spacer(),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }

  Widget _buildTestSection(ThemeData theme, CostCodeEntity mapping) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Encoding',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildTestRow(mapping, 125, '₱125'),
            _buildTestRow(mapping, 1000, '₱1,000'),
            _buildTestRow(mapping, 500, '₱500'),
            _buildTestRow(mapping, 99, '₱99'),
            _buildTestRow(mapping, 1234, '₱1,234'),
          ],
        ),
      ),
    );
  }

  Widget _buildTestRow(CostCodeEntity mapping, double cost, String display) {
    final encoded = mapping.encode(cost);
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final muted = theme.colorScheme.onSurfaceVariant;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  display,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              Icon(CupertinoIcons.forward, size: 14, color: muted),
              const SizedBox(width: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.success),
                ),
                child: Text(
                  encoded,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    color: AppColors.successDark,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: hairline)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveChanges,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startEditing(CostCodeEntity? mapping) {
    if (mapping == null) return;
    setState(() {
      _isEditing = true;
      _editedMapping = mapping;
      _errorMessage = null;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _editedMapping = null;
      _errorMessage = null;
    });
  }

  Future<void> _saveChanges() async {
    if (_editedMapping == null) return;

    // Validate mapping
    final validation = _validateMapping(_editedMapping!);
    if (validation != null) {
      setState(() => _errorMessage = validation);
      return;
    }

    // Require password verification
    final verified = await PasswordDialog.show(
      context: context,
      title: 'Confirm Changes',
      subtitle: 'Enter your password to save cost code changes',
      onVerify: (password) async {
        final authProvider = ref.read(authRepositoryProvider);
        return authProvider.verifyPassword(password);
      },
    );

    if (verified != true) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) throw Exception('Not logged in');

      final success =
          await ref.read(costCodeOperationsProvider.notifier).updateMapping(
                mapping: _editedMapping!,
                updatedBy: currentUser.id,
              );

      if (success) {
        // Log activity
        await ref.read(activityLoggerProvider).logCostCodeChanged(
              user: currentUser,
            );

        if (mounted) {
          setState(() {
            _isEditing = false;
            _editedMapping = null;
          });

          context.showSuccessSnackBar('Cost code mapping updated');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _validateMapping(CostCodeEntity mapping) {
    // Check for duplicate letters
    final letters = mapping.digitToLetter.values.toSet();
    if (letters.length != 10) {
      return 'Each digit must have a unique letter';
    }

    // Check for empty letters
    for (final entry in mapping.digitToLetter.entries) {
      if (entry.value.isEmpty) {
        return 'Letter for digit ${entry.key} cannot be empty';
      }
      if (entry.value.length > 1) {
        return 'Letter for digit ${entry.key} must be a single character';
      }
    }

    // Check special codes
    if (mapping.doubleZeroCode.isEmpty) {
      return 'Double zero code cannot be empty';
    }
    if (mapping.tripleZeroCode.isEmpty) {
      return 'Triple zero code cannot be empty';
    }

    return null;
  }

  Future<void> _resetToDefault(CostCodeEntity currentMapping) async {
    final defaultMapping = CostCodeEntity.defaultMapping();

    // Check if already default
    if (_isSameMapping(currentMapping, defaultMapping)) {
      context.showSnackBar('Already using default mapping');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Default?'),
        content: const Text(
          'This will reset the cost code mapping to the original values. '
          'This action requires password verification.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Require password verification
    final verified = await PasswordDialog.show(
      context: context,
      title: 'Confirm Reset',
      subtitle: 'Enter your password to reset cost code mapping',
      onVerify: (password) async {
        final authProvider = ref.read(authRepositoryProvider);
        return authProvider.verifyPassword(password);
      },
    );

    if (verified != true) return;

    try {
      final success =
          await ref.read(costCodeOperationsProvider.notifier).resetToDefault();

      if (success && mounted) {
        final currentUser = ref.read(currentUserProvider).value;
        if (currentUser != null) {
          await ref.read(activityLoggerProvider).logCostCodeChanged(
                user: currentUser,
              );
        }
        if (!mounted) return;
        context.showSuccessSnackBar('Cost code mapping reset to default');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Error: $e');
      }
    }
  }

  bool _isSameMapping(CostCodeEntity a, CostCodeEntity b) {
    if (a.doubleZeroCode != b.doubleZeroCode) return false;
    if (a.tripleZeroCode != b.tripleZeroCode) return false;

    for (int i = 0; i < 10; i++) {
      final digit = i.toString();
      if (a.digitToLetter[digit] != b.digitToLetter[digit]) return false;
    }

    return true;
  }
}
