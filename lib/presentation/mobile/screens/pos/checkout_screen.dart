import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
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
  }

  @override
  void dispose() {
    _amountReceivedController.dispose();
    super.dispose();
  }

  void _handleAmountChanged(String value) {
    final amount = double.tryParse(value) ?? 0;
    ref.read(cartProvider.notifier).setAmountReceived(amount);
  }

  void _handlePaymentMethodChanged(PaymentMethod method) {
    ref.read(cartProvider.notifier).setPaymentMethod(method);
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
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
                    Card(
                      margin: EdgeInsets.zero,
                      child: PaymentSection(
                        cart: cart,
                        amountController: _amountReceivedController,
                        onAmountChanged: _handleAmountChanged,
                        onPaymentMethodChanged: _handlePaymentMethodChanged,
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
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          ...cart.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == cart.items.length - 1;
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
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
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
        ],
      ),
    );
  }

  Widget _buildPaymentSummary(ThemeData theme, CartState cart) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _buildSummaryRow(
              theme,
              'Subtotal',
              '${AppConstants.currencySymbol}${cart.subtotal.toStringAsFixed(2)}',
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
              ? theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
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
            CupertinoIcons.exclamationmark_circle,
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
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: hairline)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 64,
          child: FilledButton(
            onPressed: _isProcessing ? null : () => _processCheckout(cart),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
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
                      const Icon(CupertinoIcons.checkmark_circle, size: 22),
                      const SizedBox(width: AppSpacing.sm + 4),
                      Text(
                        'Confirm Payment • ${AppConstants.currencySymbol}${cart.grandTotal.toStringAsFixed(2)}',
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Printing receipt...')),
            );
          },
          onShare: () {
            // TODO: Implement sharing
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sharing receipt...')),
            );
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
