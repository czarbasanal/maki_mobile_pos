import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Payment method selection and amount received input.
class PaymentSection extends StatelessWidget {
  final CartState cart;
  final TextEditingController amountController;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<PaymentMethod> onPaymentMethodChanged;

  const PaymentSection({
    super.key,
    required this.cart,
    required this.amountController,
    required this.onAmountChanged,
    required this.onPaymentMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment method selector
          Row(
            children: [
              const Text(
                'Payment:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SegmentedButton<PaymentMethod>(
                  segments: const [
                    ButtonSegment(
                      value: PaymentMethod.cash,
                      label: Text('Cash'),
                      icon: Icon(Icons.money),
                    ),
                    ButtonSegment(
                      value: PaymentMethod.gcash,
                      label: Text('GCash'),
                      icon: Icon(Icons.phone_android),
                    ),
                  ],
                  selected: {cart.paymentMethod},
                  onSelectionChanged: (selected) {
                    if (selected.isNotEmpty) {
                      onPaymentMethodChanged(selected.first);
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Amount received input
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount Received',
                    prefixText: '${AppConstants.currencySymbol} ',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      tooltip: 'Exact amount',
                      onPressed: () {
                        amountController.text =
                            cart.grandTotal.toStringAsFixed(2);
                        onAmountChanged(amountController.text);
                      },
                    ),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  onChanged: onAmountChanged,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Quick amount buttons
          _buildQuickAmountButtons(context),

          const SizedBox(height: 16),

          // Change display
          _buildChangeDisplay(context),
        ],
      ),
    );
  }

  Widget _buildQuickAmountButtons(BuildContext context) {
    // Common peso denominations
    final amounts = [20, 50, 100, 200, 500, 1000];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: amounts.map((amount) {
        return ActionChip(
          label: Text('${AppConstants.currencySymbol}$amount'),
          onPressed: () {
            final current = double.tryParse(amountController.text) ?? 0;
            final newAmount = current + amount;
            amountController.text = newAmount.toStringAsFixed(2);
            onAmountChanged(amountController.text);
          },
        );
      }).toList(),
    );
  }

  Widget _buildChangeDisplay(BuildContext context) {
    final theme = Theme.of(context);
    final change = cart.change;
    final isInsufficient = cart.amountReceived > 0 && !cart.isPaymentSufficient;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isInsufficient
            ? Colors.red[50]
            : cart.amountReceived > 0
                ? Colors.green[50]
                : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInsufficient
              ? Colors.red[200]!
              : cart.amountReceived > 0
                  ? Colors.green[200]!
                  : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isInsufficient ? 'Amount Short' : 'Change',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            isInsufficient
                ? '${AppConstants.currencySymbol}${(cart.grandTotal - cart.amountReceived).toStringAsFixed(2)}'
                : '${AppConstants.currencySymbol}${change.toStringAsFixed(2)}',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isInsufficient ? Colors.red : Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }
}
