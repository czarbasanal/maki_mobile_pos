import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Dialog for adjusting product stock.
class StockAdjustmentDialog extends ConsumerStatefulWidget {
  final ProductEntity product;

  const StockAdjustmentDialog({
    super.key,
    required this.product,
  });

  static Future<bool?> show({
    required BuildContext context,
    required ProductEntity product,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StockAdjustmentDialog(product: product),
    );
  }

  @override
  ConsumerState<StockAdjustmentDialog> createState() =>
      _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends ConsumerState<StockAdjustmentDialog> {
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  AdjustmentType _adjustmentType = AdjustmentType.add;
  bool _isProcessing = false;
  String? _errorMessage;

  int get _adjustmentQuantity => int.tryParse(_quantityController.text) ?? 0;

  int get _newQuantity {
    final adjustment = _adjustmentQuantity;
    if (_adjustmentType == AdjustmentType.add) {
      return widget.product.quantity + adjustment;
    } else if (_adjustmentType == AdjustmentType.remove) {
      return widget.product.quantity - adjustment;
    } else {
      return adjustment; // Set to exact value
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg - 4),
        child: Builder(builder: (context) {
          final muted = theme.colorScheme.onSurfaceVariant;
          final isDark = theme.brightness == Brightness.dark;
          final hairline =
              isDark ? AppColors.darkHairline : AppColors.lightHairline;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: hairline,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg - 4),
              // Header — outlined cube_box glyph
              Row(
                children: [
                  Icon(CupertinoIcons.cube_box, color: muted, size: 24),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adjust Stock',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.product.name,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg - 4),
              // Current vs New stock — themed Card with hairline
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStockColumn(
                        'Current',
                        '${widget.product.quantity}',
                        theme.colorScheme.onSurface,
                      ),
                      Icon(CupertinoIcons.forward, color: muted, size: 18),
                      _buildStockColumn(
                        'New',
                        '$_newQuantity',
                        _getNewQuantityColor(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg - 4),
              // Adjustment type selector
              Text(
                'Adjustment Type',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<AdjustmentType>(
                  segments: const [
                    ButtonSegment(
                      value: AdjustmentType.add,
                      icon: Icon(CupertinoIcons.add),
                      label: Text('Add'),
                    ),
                    ButtonSegment(
                      value: AdjustmentType.remove,
                      icon: Icon(CupertinoIcons.minus),
                      label: Text('Remove'),
                    ),
                    ButtonSegment(
                      value: AdjustmentType.set,
                      icon: Icon(CupertinoIcons.pencil),
                      label: Text('Set To'),
                    ),
                  ],
                  selected: {_adjustmentType},
                  onSelectionChanged: (selected) {
                    setState(() {
                      _adjustmentType = selected.first;
                      _errorMessage = null;
                    });
                  },
                ),
              ),

            const SizedBox(height: 20),

            // Quantity input
            TextField(
              controller: _quantityController,
              decoration: InputDecoration(
                labelText: _adjustmentType == AdjustmentType.set
                    ? 'New Quantity'
                    : 'Quantity',
                hintText: 'Enter quantity',
                prefixIcon: Icon(
                  _adjustmentType == AdjustmentType.add
                      ? CupertinoIcons.plus_circle
                      : _adjustmentType == AdjustmentType.remove
                          ? CupertinoIcons.minus_circle
                          : CupertinoIcons.pencil,
                ),
                suffixText: widget.product.unit,
                errorText: _errorMessage,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) {
                setState(() {
                  _errorMessage = null;
                });
              },
            ),

            const SizedBox(height: 16),

            // Quick quantity buttons
            _buildQuickQuantityButtons(),

            const SizedBox(height: 20),

            // Note input
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Reason / Note (optional)',
                hintText: 'e.g., Received shipment, Damaged items',
                prefixIcon: Icon(CupertinoIcons.doc_text),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isProcessing ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _isProcessing ? null : _handleAdjustment,
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Apply Adjustment'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
          ],
        );
        }),
      ),
    );
  }

  Widget _buildStockColumn(String label, String value, Color color) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(
          widget.product.unit,
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }

  Widget _buildQuickQuantityButtons() {
    final quickValues = [1, 5, 10, 25, 50, 100];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: quickValues.map((value) {
        return ActionChip(
          label: Text('+$value'),
          onPressed: () {
            final current = int.tryParse(_quantityController.text) ?? 0;
            _quantityController.text = (current + value).toString();
            setState(() {});
          },
        );
      }).toList(),
    );
  }

  Color _getNewQuantityColor() {
    final newQty = _newQuantity;
    if (newQty <= 0) return AppColors.error;
    if (newQty <= widget.product.reorderLevel) return AppColors.warning;
    return AppColors.success;
  }

  Future<void> _handleAdjustment() async {
    final quantity = _adjustmentQuantity;

    // Validate
    if (quantity <= 0 && _adjustmentType != AdjustmentType.set) {
      setState(() {
        _errorMessage = 'Please enter a valid quantity';
      });
      return;
    }

    if (_adjustmentType == AdjustmentType.set && quantity < 0) {
      setState(() {
        _errorMessage = 'Quantity cannot be negative';
      });
      return;
    }

    if (_adjustmentType == AdjustmentType.remove &&
        quantity > widget.product.quantity) {
      setState(() {
        _errorMessage = 'Cannot remove more than current stock';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) throw Exception('User not logged in');

      final productOps = ref.read(productOperationsProvider.notifier);

      ProductEntity? result;
      if (_adjustmentType == AdjustmentType.set) {
        // Use setStock for exact value
        result = await ref.read(productRepositoryProvider).setStock(
              productId: widget.product.id,
              newQuantity: quantity,
              updatedBy: currentUser.id,
            );
      } else {
        // Use updateStock for add/remove
        final change =
            _adjustmentType == AdjustmentType.add ? quantity : -quantity;
        result = await productOps.updateStock(
          productId: widget.product.id,
          quantityChange: change,
          updatedBy: currentUser.id,
        );
      }

      if (result != null && mounted) {
        final newQty = _newQuantity;
        Navigator.pop(context, true);
        if (mounted) {
          context.showSuccessSnackBar(
            'Stock updated: ${widget.product.name} → $newQty ${widget.product.unit}',
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });
    }
  }
}

/// Type of stock adjustment.
enum AdjustmentType {
  add,
  remove,
  set,
}
