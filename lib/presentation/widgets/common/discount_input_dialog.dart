import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';

/// Dialog for entering item-level discount.
class DiscountInputDialog extends StatefulWidget {
  final String itemName;
  final double currentDiscount;
  final DiscountType discountType;
  final double maxAmount;
  final ValueChanged<double> onApply;

  const DiscountInputDialog({
    super.key,
    required this.itemName,
    required this.currentDiscount,
    required this.discountType,
    required this.maxAmount,
    required this.onApply,
  });

  @override
  State<DiscountInputDialog> createState() => _DiscountInputDialogState();
}

class _DiscountInputDialogState extends State<DiscountInputDialog> {
  late TextEditingController _controller;
  String? _errorText;

  bool get isPercentage => widget.discountType == DiscountType.percentage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentDiscount > 0
          ? widget.currentDiscount.toStringAsFixed(isPercentage ? 0 : 2)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    final value = double.tryParse(_controller.text) ?? 0;

    setState(() {
      if (value < 0) {
        _errorText = 'Cannot be negative';
      } else if (isPercentage && value > 100) {
        _errorText = 'Cannot exceed 100%';
      } else if (!isPercentage && value > widget.maxAmount) {
        _errorText =
            'Cannot exceed item total (${AppConstants.currencySymbol}${widget.maxAmount.toStringAsFixed(2)})';
      } else {
        _errorText = null;
      }
    });
  }

  void _applyDiscount() {
    final value = double.tryParse(_controller.text) ?? 0;

    // Validate
    if (value < 0) return;
    if (isPercentage && value > 100) return;
    if (!isPercentage && value > widget.maxAmount) return;

    widget.onApply(value);
    Navigator.pop(context);
  }

  void _removeDiscount() {
    widget.onApply(0);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Apply Discount'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item name
          Text(
            widget.itemName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          // Discount type indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isPercentage ? 'Percentage Discount' : 'Amount Discount',
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Discount input
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: isPercentage ? 'Discount (%)' : 'Discount Amount',
              prefixText:
                  isPercentage ? null : '${AppConstants.currencySymbol} ',
              suffixText: isPercentage ? '%' : null,
              border: const OutlineInputBorder(),
              errorText: _errorText,
              helperText: isPercentage
                  ? 'Enter percentage (0-100)'
                  : 'Max: ${AppConstants.currencySymbol}${widget.maxAmount.toStringAsFixed(2)}',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                isPercentage
                    ? RegExp(r'^\d*\.?\d{0,1}')
                    : RegExp(r'^\d*\.?\d{0,2}'),
              ),
            ],
            onChanged: (_) => _validate(),
            onSubmitted: (_) => _applyDiscount(),
          ),

          const SizedBox(height: 16),

          // Quick percentage buttons (for percentage mode)
          if (isPercentage) _buildQuickPercentButtons(),

          // Quick amount buttons (for amount mode)
          if (!isPercentage) _buildQuickAmountButtons(),
        ],
      ),
      actions: [
        // Remove discount button
        if (widget.currentDiscount > 0)
          TextButton(
            onPressed: _removeDiscount,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),

        // Cancel
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),

        // Apply
        FilledButton(
          onPressed: _errorText == null ? _applyDiscount : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildQuickPercentButtons() {
    final percentages = [5, 10, 15, 20, 25, 50];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: percentages.map((percent) {
        return ActionChip(
          label: Text('$percent%'),
          onPressed: () {
            _controller.text = percent.toString();
            _validate();
          },
        );
      }).toList(),
    );
  }

  Widget _buildQuickAmountButtons() {
    // Calculate reasonable quick amounts based on item total
    final maxAmount = widget.maxAmount;
    List<int> amounts;

    if (maxAmount <= 100) {
      amounts = [5, 10, 20, 50];
    } else if (maxAmount <= 500) {
      amounts = [10, 20, 50, 100];
    } else if (maxAmount <= 1000) {
      amounts = [50, 100, 200, 500];
    } else {
      amounts = [100, 200, 500, 1000];
    }

    // Filter amounts that don't exceed max
    amounts = amounts.where((a) => a <= maxAmount).toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: amounts.map((amount) {
        return ActionChip(
          label: Text('${AppConstants.currencySymbol}$amount'),
          onPressed: () {
            _controller.text = amount.toStringAsFixed(2);
            _validate();
          },
        );
      }).toList(),
    );
  }
}
