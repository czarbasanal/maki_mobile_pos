import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/widgets/common/password_dialog.dart';
import 'package:maki_mobile_pos/presentation/widgets/settings/cost_code_editor.dart';
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
        title: const Text('Cost Code Settings'),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _cancelEditing,
              child: const Text('Cancel'),
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
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
              color: Colors.grey[600],
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
                icon: const Icon(Icons.restore),
                label: const Text('Reset to Default'),
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Cost Codes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cost codes hide actual product costs from unauthorized users. '
                  'Only admins can view or modify this mapping.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMappingDisplay(ThemeData theme, CostCodeEntity mapping) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Digit',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                Expanded(
                  child: Text(
                    'Code',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const Divider(),
            // Mapping rows
            ...List.generate(10, (index) {
              final digit = index.toString();
              final letter = mapping.digitToLetter[digit] ?? '?';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          digit,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(
                        Icons.arrow_forward,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              digits,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.arrow_forward, color: Colors.grey[400], size: 16),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              code,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const Spacer(),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              display,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Text(
              encoded,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: Colors.green[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
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

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cost code mapping updated'),
              backgroundColor: Colors.green,
            ),
          );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already using default mapping')),
      );
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cost code mapping reset to default'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
