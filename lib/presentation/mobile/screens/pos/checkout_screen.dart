import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/process_sale_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/checkout_success_dialog.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/payment_section.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/receipt_widget.dart';

/// Checkout confirmation screen.
///
/// Shows the order, takes payment input (method + amount received),
/// and confirms the sale. The cart provider supplies the items and
/// keeps payment-method / amount-received state across navigation.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late final TextEditingController _amountReceivedController;
  late final TextEditingController _splitController;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill from CartState in case the user backed out and returned,
    // or arrived from drafts with a previously stored amount.
    final initialAmount = ref.read(cartProvider).amountReceived;
    _amountReceivedController = TextEditingController(
      text: initialAmount > 0 ? initialAmount.toStringAsFixed(2) : '',
    );
    _splitController = TextEditingController();
  }

  @override
  void dispose() {
    _amountReceivedController.dispose();
    _splitController.dispose();
    super.dispose();
  }

  void _handleAmountChanged(String value) {
    final amount = double.tryParse(value) ?? 0;
    ref.read(cartProvider.notifier).setAmountReceived(amount);
  }

  void _handlePaymentMethodChanged(PaymentMethod method) {
    ref.read(cartProvider.notifier).setPaymentMethod(method);
    _splitController.clear();
  }

  void _handleSecondaryMethodChanged(PaymentMethod method) {
    ref.read(cartProvider.notifier).setSecondaryMethod(method);
  }

  void _handleSplitAmountChanged(String value) {
    ref.read(cartProvider.notifier).setSplitAmount(double.tryParse(value) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.appBarTheme.backgroundColor,
            boxShadow: AppShadows.pinnedHeader(
              dark: theme.brightness == Brightness.dark,
            ),
          ),
          child: AppBar(
            title: const Text('Checkout'),
            leading: IconButton(
              icon: const Icon(LucideIcons.chevronLeft),
              onPressed: _isProcessing ? null : () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader('Order Items'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildItemsList(theme, cart),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionHeader('Payment Summary'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildPaymentSummary(theme, cart),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionHeader('Payment'),
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      child: PaymentSection(
                        cart: cart,
                        amountController: _amountReceivedController,
                        splitController: _splitController,
                        onAmountChanged: _handleAmountChanged,
                        onPaymentMethodChanged: _handlePaymentMethodChanged,
                        onSecondaryMethodChanged:
                            _handleSecondaryMethodChanged,
                        onSplitAmountChanged: _handleSplitAmountChanged,
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _buildErrorMessage(),
                    ],
                  ],
                ),
              ),
            ),
            _buildConfirmButton(theme, cart),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList(ThemeData theme, CartState cart) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    return AppCard(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ...cart.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast =
                index == cart.items.length - 1 && cart.laborLines.isEmpty;
            final netAmount = item.calculateNetAmount(
              isPercentage: cart.isPercentageDiscount,
            );

            return Container(
              padding: const EdgeInsets.all(AppSpacing.sm + 4),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(bottom: BorderSide(color: hairline)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quantity badge — outlined primary, no fill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: theme.colorScheme.primary),
                    ),
                    child: Text(
                      '×${item.quantity}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: AppTextStyles.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          item.sku,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: muted),
                        ),
                        if (item.hasDiscount)
                          Text(
                            cart.isPercentageDiscount
                                ? '${item.discountValue.toStringAsFixed(0)}% off'
                                : '${AppConstants.currencySymbol}${item.discountValue.toStringAsFixed(2)} off',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.successDark,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${AppConstants.currencySymbol}${netAmount.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
          ...cart.laborLines.asMap().entries.map((entry) {
            final index = entry.key;
            final line = entry.value;
            final isLast = index == cart.laborLines.length - 1;
            return Container(
              padding: const EdgeInsets.all(AppSpacing.sm + 4),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(bottom: BorderSide(color: hairline)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: theme.colorScheme.primary),
                    ),
                    child: Icon(
                      LucideIcons.wrench,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Text(
                      line.description.isEmpty ? 'Service' : line.description,
                      style: AppTextStyles.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${AppConstants.currencySymbol}${line.fee.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary(ThemeData theme, CartState cart) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _buildSummaryRow(
              theme,
              cart.laborLines.isEmpty ? 'Subtotal' : 'Parts subtotal',
              '${AppConstants.currencySymbol}${cart.partsSubtotal.toStringAsFixed(2)}',
            ),
            if (cart.hasDiscount) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildSummaryRow(
                theme,
                'Discount',
                '-${AppConstants.currencySymbol}${cart.totalDiscount.toStringAsFixed(2)}',
                valueColor: AppColors.successDark,
              ),
            ],
            if (cart.laborLines.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildSummaryRow(
                theme,
                'Labor (${cart.laborLines.length} '
                    'service${cart.laborLines.length == 1 ? '' : 's'})',
                '${AppConstants.currencySymbol}${cart.laborSubtotal.toStringAsFixed(2)}',
              ),
              if (cart.mechanicName != null &&
                  cart.mechanicName!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Mechanic: ${cart.mechanicName}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm + 4),
              child: Divider(height: 1),
            ),
            _buildSummaryRow(
              theme,
              'Total',
              '${AppConstants.currencySymbol}${cart.grandTotal.toStringAsFixed(2)}',
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    ThemeData theme,
    String label,
    String value, {
    bool isTotal = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)
              : theme.textTheme.bodyMedium,
        ),
        Text(
          value,
          style: isTotal
              ? TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                  color: theme.colorScheme.primary,
                )
              : theme.textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                  fontWeight: valueColor != null ? FontWeight.w600 : null,
                ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.alertTriangle,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton(ThemeData theme, CartState cart) {
    final isDark = theme.brightness == Brightness.dark;
    final enabled = !_isProcessing && cart.canCheckout;
    return Container(
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        boxShadow: AppShadows.pinnedFooter(dark: isDark),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: enabled ? AppShadows.confirmButton(dark: isDark) : null,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: enabled ? () => _processCheckout(cart) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.success.withValues(alpha: 0.4),
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.checkCircle2, size: 22),
                          const SizedBox(width: AppSpacing.sm + 4),
                          Text(
                            'Confirm Payment • ${AppConstants.currencySymbol}'
                            '${cart.grandTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _processCheckout(CartState cart) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final useCase = ProcessSaleUseCase(
        saleRepository: ref.read(saleRepositoryProvider),
        productRepository: ref.read(productRepositoryProvider),
        draftRepository: ref.read(draftRepositoryProvider),
      );

      final cartNotifier = ref.read(cartProvider.notifier);
      final sale = cartNotifier.toSale(
        saleNumber: '',
        cashierId: currentUser.id,
        cashierName: currentUser.displayName,
      );

      final result = await useCase.execute(sale: sale);

      if (result.success && result.sale != null) {
        cartNotifier.resetAfterCheckout();
        ref.read(selectedDraftProvider.notifier).state = null;

        ref.invalidate(todaysSalesProvider);
        ref.invalidate(todaysSalesSummaryProvider);
        ref.invalidate(activeDraftsProvider);
        ref.invalidate(productsProvider);
        ref.invalidate(lowStockProductsProvider);

        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => CheckoutSuccessDialog(
              sale: result.sale!,
              warnings: result.warnings,
              onDone: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to POS
              },
              onPrintReceipt: () => _printReceipt(result.sale!),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = result.errorMessage ?? 'Failed to process sale';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _printReceipt(dynamic sale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => ReceiptWidget(
          sale: sale,
          scrollController: scrollController,
          onPrint: () {
            // TODO: Implement actual printing
            context.showSnackBar('Printing receipt...');
          },
          onShare: () {
            // TODO: Implement sharing
            context.showSnackBar('Sharing receipt...');
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}
