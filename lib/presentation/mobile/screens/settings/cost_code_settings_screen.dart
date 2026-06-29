import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/password_dialog.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/settings/cost_code_editor.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

const String _mono = AppTextStyles.monoFontFamily;

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
          icon: const Icon(LucideIcons.chevronLeft),
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
              icon: const Icon(LucideIcons.squarePen),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card
          _buildInfoCard(theme),

          _sectionHeading(theme, 'Digit to Letter Mapping'),
          _sectionHelper(theme, 'Each digit (0–9) is encoded as a letter to hide costs.'),
          const SizedBox(height: 12),

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

          _sectionHeading(theme, 'Special Codes'),
          const SizedBox(height: 8),
          _buildSpecialCodesCard(theme, displayMapping),

          _sectionHeading(theme, 'Test Encoding'),
          const SizedBox(height: 8),
          _buildTestSection(theme, displayMapping),

          // Reset to default button (only when not editing)
          if (!_isEditing) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _resetToDefault(mapping),
                icon: const Icon(LucideIcons.rotateCcw, size: 17),
                label: const Text('Reset to Default'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeading(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 3),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _sectionHelper(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final tileBg = dark ? const Color(0x24E8B84C) : const Color(0x12283E46);
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              LucideIcons.info,
              color: theme.colorScheme.primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Cost Codes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Cost codes hide actual product costs from unauthorized users. '
                  'Only admins can view or modify this mapping.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Recessed mono cell (digit / special-code source).
  Widget _digitCell(ThemeData theme, String text, {bool expand = true}) {
    final dark = theme.brightness == Brightness.dark;
    final fill = dark ? AppColors.darkCanvas : AppColors.lightSurfaceMuted;
    final border = dark ? AppColors.darkInputBorder : AppColors.lightHairline;
    final cell = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: _mono,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
    return expand ? Expanded(child: cell) : cell;
  }

  /// Slate/gold-outlined mono cell (encoded code).
  Widget _codeCell(ThemeData theme, String text, {bool expand = true}) {
    final cell = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.primary, width: 1.3),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: _mono,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
    return expand ? Expanded(child: cell) : cell;
  }

  Widget _buildMappingDisplay(ThemeData theme, CostCodeEntity mapping) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: List.generate(10, (index) {
          final digit = index.toString();
          final letter = mapping.digitToLetter[digit] ?? '?';
          return Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 9),
            child: Row(
              children: [
                _digitCell(theme, digit),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(LucideIcons.arrowRight, size: 16, color: muted),
                ),
                _codeCell(theme, letter),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSpecialCodesCard(ThemeData theme, CostCodeEntity mapping) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _buildSpecialCodeRow(theme, '00', mapping.doubleZeroCode, 'Double Zero'),
          const SizedBox(height: 9),
          _buildSpecialCodeRow(theme, '000', mapping.tripleZeroCode, 'Triple Zero'),
        ],
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
    return Row(
      children: [
        _digitCell(theme, digits, expand: false),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(LucideIcons.arrowRight, size: 16, color: muted),
        ),
        _codeCell(theme, code, expand: false),
        const Spacer(),
        Text(label, style: TextStyle(fontSize: 12.5, color: muted)),
      ],
    );
  }

  Widget _buildTestSection(ThemeData theme, CostCodeEntity mapping) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          _buildTestRow(theme, mapping, 125, '₱125'),
          _buildTestRow(theme, mapping, 1000, '₱1,000'),
          _buildTestRow(theme, mapping, 500, '₱500'),
          _buildTestRow(theme, mapping, 99, '₱99'),
          _buildTestRow(theme, mapping, 1234, '₱1,234'),
        ],
      ),
    );
  }

  Widget _buildTestRow(
    ThemeData theme,
    CostCodeEntity mapping,
    double cost,
    String display,
  ) {
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final encoded = mapping.encode(cost);
    final chipBorder = dark ? AppColors.success.withValues(alpha: 0.5) : AppColors.success;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              display,
              style: TextStyle(
                fontFamily: _mono,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Icon(LucideIcons.arrowRight, size: 15, color: muted),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: chipBorder),
            ),
            child: Text(
              encoded,
              style: TextStyle(
                fontFamily: _mono,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.successText(dark),
              ),
            ),
          ),
        ],
      ),
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
    if (!mounted) return;

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
