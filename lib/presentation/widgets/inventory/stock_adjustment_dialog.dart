import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Adjust Stock',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.product.name,
                        style: TextStyle(color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Current stock display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStockColumn(
                    'Current',
                    '${widget.product.quantity}',
                    Colors.grey[700]!,
                  ),
                  Icon(Icons.arrow_forward, color: Colors.grey[400]),
                  _buildStockColumn(
                    'New',
                    '$_newQuantity',
                    _getNewQuantityColor(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Adjustment type selector
            const Text(
              'Adjustment Type',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<AdjustmentType>(
              segments: const [
                ButtonSegment(
                  value: AdjustmentType.add,
                  icon: Icon(Icons.add),
                  label: Text('Add'),
                ),
                ButtonSegment(
                  value: AdjustmentType.remove,
                  icon: Icon(Icons.remove),
                  label: Text('Remove'),
                ),
                ButtonSegment(
                  value: AdjustmentType.set,
                  icon: Icon(Icons.edit),
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

            const SizedBox(height: 20),

            // Quantity input
            TextField(
              controller: _quantityController,
              decoration: InputDecoration(
                labelText: _adjustmentType == AdjustmentType.set
                    ? 'New Quantity'
                    : 'Quantity',
                hintText: 'Enter quantity',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(
                  _adjustmentType == AdjustmentType.add
                      ? Icons.add_circle
                      : _adjustmentType == AdjustmentType.remove
                          ? Icons.remove_circle
                          : Icons.edit,
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
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
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
        ),
      ),
    );
  }

  Widget _buildStockColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          widget.product.unit,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
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
    if (newQty < 0) return Colors.red;
    if (newQty == 0) return Colors.red;
    if (newQty <= widget.product.reorderLevel) return Colors.orange;
    return Colors.green;
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
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stock updated: ${widget.product.name} → ${_newQuantity} ${widget.product.unit}',
            ),
            backgroundColor: Colors.green,
          ),
        );
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
