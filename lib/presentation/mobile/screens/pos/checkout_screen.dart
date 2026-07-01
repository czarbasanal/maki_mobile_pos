import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
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

  // One stable id per checkout attempt. Reused across retries on this screen
  // (so a retry returns the existing sale instead of writing a duplicate); a
  // new checkout is a new screen instance and gets a fresh id.
  late final String _checkoutId = const Uuid().v4();
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
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.primary),
                    ),
                    child: Text(
                      '×${item.quantity}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
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
                          style:
                              AppTextStyles.productName.copyWith(fontSize: 14),
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
                                : '${item.discountValue.toCurrency()} off',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.successText(isDark),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    netAmount.toCurrency(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
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
                      style: AppTextStyles.productName.copyWith(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    line.fee.toCurrency(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
    final isDark = theme.brightness == Brightness.dark;
    final mechanic = cart.mechanicName;
    // Mechanic folded onto the Labor row ("Labor · Mang Tonio") per the handoff.
    final laborLabel = (mechanic != null && mechanic.isNotEmpty)
        ? 'Labor · $mechanic'
        : 'Labor';
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            SummaryRow(
              label: cart.laborLines.isEmpty ? 'Subtotal' : 'Parts subtotal',
              value:
                  cart.partsSubtotal.toCurrency(),
            ),
            if (cart.hasDiscount) ...[
              const SizedBox(height: 6),
              SummaryRow(
                label: 'Discount',
                value:
                    '-${cart.totalDiscount.toCurrency()}',
                valueColor: AppColors.successText(isDark),
              ),
            ],
            if (cart.laborLines.isNotEmpty) ...[
              const SizedBox(height: 6),
              SummaryRow(
                label: laborLabel,
                value:
                    cart.laborSubtotal.toCurrency(),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm + 1),
              child: Divider(height: 1),
            ),
            SummaryRow(
              label: 'Total',
              value:
                  cart.grandTotal.toCurrency(),
              isTotal: true,
            ),
          ],
        ),
      ),
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
                          const Icon(LucideIcons.checkCircle2, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Confirm Payment · ${AppConstants.currencySymbol}'
                            '${cart.grandTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
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
    // Re-entry guard: a same-frame double-tap can fire this twice before the
    // button rebuilds disabled. Bail if a checkout is already in flight so we
    // never write two sales (the sale write is not idempotent).
    if (_isProcessing) return;
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

      final result = await useCase.execute(sale: sale, checkoutId: _checkoutId);

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
      backgroundColor: Colors.transparent,
      barrierColor: AppDialog.scrimColor(
          Theme.of(context).brightness == Brightness.dark),
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
        fontSize: 11,
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}
