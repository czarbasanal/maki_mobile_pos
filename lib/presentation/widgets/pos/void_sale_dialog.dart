import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/void_sale_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/widgets/common/password_dialog.dart';

/// Dialog for voiding a sale with reason and password verification.
class VoidSaleDialog extends ConsumerStatefulWidget {
  final SaleEntity sale;
  final VoidCallback onVoided;

  const VoidSaleDialog({
    super.key,
    required this.sale,
    required this.onVoided,
  });

  /// Shows the void sale dialog.
  static Future<bool> show({
    required BuildContext context,
    required SaleEntity sale,
    required VoidCallback onVoided,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VoidSaleDialog(
        sale: sale,
        onVoided: onVoided,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<VoidSaleDialog> createState() => _VoidSaleDialogState();
}

class _VoidSaleDialogState extends ConsumerState<VoidSaleDialog> {
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;
  bool _restoreInventory = true;
  String? _errorMessage;

  // Common void reasons for quick selection
  static const List<String> _commonReasons = [
    'Customer changed mind',
    'Wrong items entered',
    'Payment issue',
    'Duplicate transaction',
    'Price error',
    'Other',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.cancel_outlined,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Void Sale',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sale info
              _buildSaleInfo(theme),

              const SizedBox(height: 20),

              // Warning
              _buildWarningBanner(theme),

              const SizedBox(height: 20),

              // Common reasons
              Text(
                'Select a reason:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildReasonChips(),

              const SizedBox(height: 16),

              // Custom reason input
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for voiding',
                  hintText: 'Enter detailed reason...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
                maxLines: 2,
                maxLength: 200,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a reason';
                  }
                  if (value.trim().length < 5) {
                    return 'Reason must be at least 5 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Restore inventory option
              CheckboxListTile(
                value: _restoreInventory,
                onChanged: (value) {
                  setState(() {
                    _restoreInventory = value ?? true;
                  });
                },
                title: const Text('Restore inventory'),
                subtitle: const Text(
                  'Return items back to stock',
                  style: TextStyle(fontSize: 12),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                _buildErrorBanner(theme),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isProcessing ? null : _handleVoid,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: _isProcessing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Void Sale'),
        ),
      ],
    );
  }

  Widget _buildSaleInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.sale.saleNumber,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${AppConstants.currencySymbol}${widget.sale.grandTotal.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.sale.totalItemCount} item(s) • ${widget.sale.cashierName}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.red[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This action cannot be undone',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'The sale will be marked as voided and recorded in the audit log.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _commonReasons.map((reason) {
        final isSelected = _reasonController.text == reason;
        return ChoiceChip(
          label: Text(reason),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _reasonController.text = reason == 'Other' ? '' : reason;
              });
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildErrorBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[700], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleVoid() async {
    if (!_formKey.currentState!.validate()) return;

    // Show password dialog
    final passwordVerified = await PasswordDialog.show(
      context: context,
      title: 'Confirm Void',
      subtitle: 'Enter your password to void this sale.',
      confirmButtonText: 'Verify & Void',
      confirmButtonColor: Colors.red,
      onVerify: (password) async {
        return await _processVoid(password);
      },
    );

    if (passwordVerified && mounted) {
      Navigator.pop(context, true);
      widget.onVoided();
    }
  }

  Future<bool> _processVoid(String password) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final useCase = VoidSaleUseCase(
        saleRepository: ref.read(saleRepositoryProvider),
        productRepository: ref.read(productRepositoryProvider),
        authRepository: ref.read(authRepositoryProvider),
      );

      final result = await useCase.execute(
        saleId: widget.sale.id,
        password: password,
        reason: _reasonController.text.trim(),
        voidedBy: currentUser.id,
        voidedByName: currentUser.displayName,
        restoreInventory: _restoreInventory,
      );

      if (result.success) {
        // Invalidate providers
        ref.invalidate(todaysSalesProvider);
        ref.invalidate(todaysSalesSummaryProvider);
        ref.invalidate(saleByIdProvider(widget.sale.id));

        if (result.hasWarnings && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Warnings: ${result.warnings.join(", ")}'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        return true;
      } else {
        setState(() {
          _errorMessage = result.errorMessage ?? 'Failed to void sale';
          _isProcessing = false;
        });
        return false;
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });
      return false;
    }
  }
}
