import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// Dialog for entering item-level discount.
///
/// The discount-type toggle (Amount vs Percentage) is hosted here rather
/// than at the cart level. Type is a cart-wide property in the data
/// model — switching it while other cart items already have discounts
/// is a destructive change, so the modal confirms before resetting.
class DiscountInputDialog extends StatefulWidget {
  final String itemName;
  final double currentDiscount;
  final DiscountType discountType;
  final double maxAmount;
  final ValueChanged<double> onApply;

  /// Called when the user toggles the discount type inside the dialog.
  /// The caller is expected to update the cart's discount-type state and
  /// reset other items' discount values when [hasOtherDiscounts] is true.
  final ValueChanged<DiscountType>? onTypeChanged;

  /// True if any cart item *other* than the one being edited currently
  /// has a non-zero discount. Used to gate the confirmation step when
  /// the user toggles type.
  final bool hasOtherDiscounts;

  const DiscountInputDialog({
    super.key,
    required this.itemName,
    required this.currentDiscount,
    required this.discountType,
    required this.maxAmount,
    required this.onApply,
    this.onTypeChanged,
    this.hasOtherDiscounts = false,
  });

  @override
  State<DiscountInputDialog> createState() => _DiscountInputDialogState();
}

class _DiscountInputDialogState extends State<DiscountInputDialog> {
  late TextEditingController _controller;
  late DiscountType _discountType;
  String? _errorText;

  bool get _isPercentage => _discountType == DiscountType.percentage;

  @override
  void initState() {
    super.initState();
    _discountType = widget.discountType;
    _controller = TextEditingController(
      text: widget.currentDiscount > 0
          ? widget.currentDiscount.toStringAsFixed(_isPercentage ? 0 : 2)
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
      } else if (_isPercentage && value > 100) {
        _errorText = 'Cannot exceed 100%';
      } else if (!_isPercentage && value > widget.maxAmount) {
        _errorText =
            'Cannot exceed item total (${AppConstants.currencySymbol}${widget.maxAmount.toStringAsFixed(2)})';
      } else {
        _errorText = null;
      }
    });
  }

  Future<void> _toggleType(DiscountType newType) async {
    if (newType == _discountType) return;

    // Switching type changes the meaning of every existing discount value
    // on the cart (50% vs ₱50). When other items already have a discount,
    // confirm before letting it reset them.
    if (widget.hasOtherDiscounts) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Change Discount Type?'),
          content: const Text(
            'Other cart items already have discounts in the current type. '
            'Switching will reset all item discounts to zero.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Switch'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _discountType = newType;
      _controller.clear();
      _errorText = null;
    });
    widget.onTypeChanged?.call(newType);
  }

  void _applyDiscount() {
    final value = double.tryParse(_controller.text) ?? 0;

    if (value < 0) return;
    if (_isPercentage && value > 100) return;
    if (!_isPercentage && value > widget.maxAmount) return;

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
    final muted = theme.colorScheme.onSurfaceVariant;

    return AlertDialog(
      title: const Text('Apply Discount'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.itemName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          // Discount type toggle — hosted in the modal now.
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<DiscountType>(
              segments: const [
                ButtonSegment(
                  value: DiscountType.amount,
                  label: Text('Amount'),
                  icon: Icon(AppIcons.peso),
                ),
                ButtonSegment(
                  value: DiscountType.percentage,
                  label: Text('Percent'),
                  icon: Icon(CupertinoIcons.percent),
                ),
              ],
              selected: {_discountType},
              onSelectionChanged: (selected) {
                if (selected.isNotEmpty) {
                  _toggleType(selected.first);
                }
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Discount input
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: _isPercentage ? 'Discount (%)' : 'Discount Amount',
              prefixText:
                  _isPercentage ? null : '${AppConstants.currencySymbol} ',
              suffixText: _isPercentage ? '%' : null,
              errorText: _errorText,
              helperText: _isPercentage
                  ? 'Enter percentage (0-100)'
                  : 'Max: ${AppConstants.currencySymbol}${widget.maxAmount.toStringAsFixed(2)}',
              helperStyle: TextStyle(color: muted),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                _isPercentage
                    ? RegExp(r'^\d*\.?\d{0,1}')
                    : RegExp(r'^\d*\.?\d{0,2}'),
              ),
            ],
            onChanged: (_) => _validate(),
            onSubmitted: (_) => _applyDiscount(),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_isPercentage)
            _buildQuickPercentButtons()
          else
            _buildQuickAmountButtons(),
        ],
      ),
      actions: [
        if (widget.currentDiscount > 0)
          TextButton(
            onPressed: _removeDiscount,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
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
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
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

    amounts = amounts.where((a) => a <= maxAmount).toList();

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
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
