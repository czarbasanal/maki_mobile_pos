import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';

/// Payment method selection and amount inputs.
///
/// Single methods (Cash/GCash/Maya) take a single amount. Mixed splits cash +
/// one digital method; Salmon takes a downpayment (any method) with the
/// remainder recorded as a Salmon receivable.
class PaymentSection extends StatelessWidget {
  final CartState cart;
  final TextEditingController amountController;
  final TextEditingController splitController;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<PaymentMethod> onPaymentMethodChanged;
  final ValueChanged<PaymentMethod> onSecondaryMethodChanged;
  final ValueChanged<String> onSplitAmountChanged;

  const PaymentSection({
    super.key,
    required this.cart,
    required this.amountController,
    required this.splitController,
    required this.onAmountChanged,
    required this.onPaymentMethodChanged,
    required this.onSecondaryMethodChanged,
    required this.onSplitAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [Colors.black, Colors.black, Colors.transparent],
              stops: const [0.0, 0.9, 1.0],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 24),
              child: Row(
                children: [
                  for (final m in const [
                    PaymentMethod.cash,
                    PaymentMethod.gcash,
                    PaymentMethod.maya,
                    PaymentMethod.mixed,
                    PaymentMethod.salmon,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: _PaymentMethodChip(
                        method: m,
                        selected: cart.paymentMethod == m,
                        onTap: () => onPaymentMethodChanged(m),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._buildInputs(context),
        ],
      ),
    );
  }

  List<Widget> _buildInputs(BuildContext context) {
    switch (cart.paymentMethod) {
      case PaymentMethod.mixed:
        return _buildMixedInputs(context);
      case PaymentMethod.salmon:
        return _buildSalmonInputs(context);
      default:
        return _buildSingleInputs(context);
    }
  }

  List<Widget> _buildSingleInputs(BuildContext context) {
    return [
      _buildAmountReceivedField(context),
      const SizedBox(height: AppSpacing.sm + 2),
      _buildQuickAmountButtons(context),
      const SizedBox(height: AppSpacing.md),
      if (cart.paymentMethod == PaymentMethod.cash) _buildChangeDisplay(context),
    ];
  }

  /// Amount-received entry as an elevated pill (₱ prefix + value + inline
  /// "Exact" fill button), matching the handoff. No floating label — the
  /// PAYMENT section header and selected method supply the context.
  Widget _buildAmountReceivedField(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return AppCard(
      radius: AppRadius.field,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Text(
            AppConstants.currencySymbol,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: amountController,
              decoration: const InputDecoration(
                hintText: '0.00',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              onChanged: onAmountChanged,
            ),
          ),
          InkWell(
            onTap: () {
              amountController.text = cart.grandTotal.toStringAsFixed(2);
              onAmountChanged(amountController.text);
            },
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.checkCheck,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Exact',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMixedInputs(BuildContext context) {
    final theme = Theme.of(context);
    final digital = cart.secondaryMethod == PaymentMethod.maya
        ? PaymentMethod.maya
        : PaymentMethod.gcash;
    final cashPortion = cart.grandTotal - cart.splitAmount;
    return [
      SegmentedButton<PaymentMethod>(
        segments: const [
          ButtonSegment(value: PaymentMethod.gcash, label: Text('GCash')),
          ButtonSegment(value: PaymentMethod.maya, label: Text('Maya')),
        ],
        selected: {digital},
        onSelectionChanged: (s) => onSecondaryMethodChanged(s.first),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: splitController,
        decoration: InputDecoration(
          labelText: '${digital.displayName} amount',
          prefixText: '${AppConstants.currencySymbol} ',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        onChanged: onSplitAmountChanged,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Cash portion: ${cashPortion.toCurrency()}',
        style: theme.textTheme.titleMedium,
      ),
    ];
  }

  List<Widget> _buildSalmonInputs(BuildContext context) {
    final theme = Theme.of(context);
    final dp = cart.secondaryMethod ?? PaymentMethod.cash;
    final balance = cart.grandTotal - cart.splitAmount;
    return [
      SegmentedButton<PaymentMethod>(
        segments: const [
          ButtonSegment(value: PaymentMethod.cash, label: Text('Cash')),
          ButtonSegment(value: PaymentMethod.gcash, label: Text('GCash')),
          ButtonSegment(value: PaymentMethod.maya, label: Text('Maya')),
        ],
        selected: {dp == PaymentMethod.salmon ? PaymentMethod.cash : dp},
        onSelectionChanged: (s) => onSecondaryMethodChanged(s.first),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: splitController,
        decoration: InputDecoration(
          labelText: 'Downpayment',
          prefixText: '${AppConstants.currencySymbol} ',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        onChanged: onSplitAmountChanged,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Salmon balance: ${balance.toCurrency()}',
        style: theme.textTheme.titleMedium,
      ),
    ];
  }

  Widget _buildQuickAmountButtons(BuildContext context) {
    const amounts = [100, 200, 500, 1000];

    void add(int amount) {
      final current = double.tryParse(amountController.text) ?? 0;
      final newAmount = current + amount;
      amountController.text = newAmount.toStringAsFixed(2);
      onAmountChanged(amountController.text);
    }

    return Row(
      children: [
        for (var i = 0; i < amounts.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _QuickAmountButton(
              amount: amounts[i],
              onTap: () => add(amounts[i]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChangeDisplay(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final change = cart.change;
    final isInsufficient = cart.amountReceived > 0 && !cart.isPaymentValid;
    final hasReceipt = cart.amountReceived > 0;

    // Filled tint carries status: success when sufficient, error when short,
    // quiet muted fill before any tender is entered.
    final Color fill;
    if (isInsufficient) {
      fill = AppColors.error.withValues(alpha: isDark ? 0.18 : 0.10);
    } else if (hasReceipt) {
      fill = AppColors.successFill(isDark);
    } else {
      fill = isDark ? AppColors.darkSurfaceMuted : AppColors.lightSurfaceMuted;
    }
    // Content colour: green when sufficient, red when short, muted before
    // any tender is entered.
    final Color contentColor;
    if (!hasReceipt) {
      contentColor = theme.colorScheme.onSurfaceVariant;
    } else if (isInsufficient) {
      contentColor = AppColors.error;
    } else {
      contentColor = AppColors.successText(isDark);
    }
    // Dark mode draws a faint matching border (the light tint is too quiet on
    // the dark canvas on its own) — mirrors the handoff.
    final Border? border = (isDark && hasReceipt)
        ? Border.all(
            color: (isInsufficient ? AppColors.error : AppColors.success)
                .withValues(alpha: 0.4),
          )
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: fill,
        border: border,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isInsufficient ? 'Amount Short' : 'Change',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: contentColor,
            ),
          ),
          Text(
            isInsufficient
                ? '${AppConstants.currencySymbol}'
                    '${(cart.grandTotal - cart.amountReceived).toStringAsFixed(2)}'
                : change.toCurrency(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: contentColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single payment-method pill chip: filled slate/gold when selected,
/// card surface + hairline + muted icon otherwise.
class _PaymentMethodChip extends StatelessWidget {
  const _PaymentMethodChip({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon {
    switch (method) {
      case PaymentMethod.cash:
        return LucideIcons.banknote;
      case PaymentMethod.gcash:
        return LucideIcons.smartphone;
      case PaymentMethod.maya:
        return LucideIcons.wallet;
      case PaymentMethod.mixed:
        return LucideIcons.layers;
      case PaymentMethod.salmon:
        return LucideIcons.fish;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final surface = isDark ? AppColors.darkCard : AppColors.lightCard;
    final muted = theme.colorScheme.onSurfaceVariant;
    final fg = selected ? theme.colorScheme.onPrimary : muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: selected ? null : Border.all(color: hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              method.displayName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A quick-amount preset button: equal-width card on the surface, adds its
/// amount to the tender on tap. Matches the handoff's 4-up button row.
class _QuickAmountButton extends StatelessWidget {
  const _QuickAmountButton({required this.amount, required this.onTap});

  final int amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final surface = isDark ? AppColors.darkCard : AppColors.lightCard;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hairline),
          // Quiet lift in light mode; the dark hairline carries it in dark.
          boxShadow: isDark
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x0D111C1D),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
        child: Text(
          '${AppConstants.currencySymbol}$amount',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
