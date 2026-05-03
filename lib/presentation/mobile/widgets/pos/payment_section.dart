import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment method selector — full-width segmented control,
          // no prefix label (the segmented appearance is self-explanatory).
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<PaymentMethod>(
              segments: const [
                ButtonSegment(
                  value: PaymentMethod.maya,
                  label: Text('Maya'),
                  icon: Icon(CupertinoIcons.creditcard),
                ),
                ButtonSegment(
                  value: PaymentMethod.cash,
                  label: Text('Cash'),
                  icon: Icon(AppIcons.peso),
                ),
                ButtonSegment(
                  value: PaymentMethod.gcash,
                  label: Text('GCash'),
                  icon: Icon(CupertinoIcons.device_phone_portrait),
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
          const SizedBox(height: AppSpacing.md),
          // Amount received input — theme-driven outlined input.
          TextField(
            controller: amountController,
            decoration: InputDecoration(
              labelText: 'Amount Received',
              prefixText: '${AppConstants.currencySymbol} ',
              suffixIcon: IconButton(
                icon: const Icon(CupertinoIcons.checkmark_circle),
                tooltip: 'Exact amount',
                onPressed: () {
                  amountController.text = cart.grandTotal.toStringAsFixed(2);
                  onAmountChanged(amountController.text);
                },
              ),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            onChanged: onAmountChanged,
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          _buildQuickAmountButtons(context),
          const SizedBox(height: AppSpacing.md),
          _buildChangeDisplay(context),
        ],
      ),
    );
  }

  Widget _buildQuickAmountButtons(BuildContext context) {
    final amounts = [100, 200, 500, 1000];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
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
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final change = cart.change;
    final isInsufficient =
        cart.amountReceived > 0 && !cart.isPaymentSufficient;
    final hasReceipt = cart.amountReceived > 0;

    // Border carries status: red when short, green when sufficient,
    // hairline-neutral when no payment yet.
    final borderColor = isInsufficient
        ? AppColors.error
        : hasReceipt
            ? AppColors.success
            : hairline;
    final valueColor =
        isInsufficient ? AppColors.error : AppColors.successDark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor),
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
              fontWeight: FontWeight.w600,
              color: hasReceipt ? valueColor : null,
            ),
          ),
        ],
      ),
    );
  }
}
