import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/process_sale_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/widgets/pos/checkout_success_dialog.dart';
import 'package:maki_mobile_pos/presentation/widgets/pos/receipt_widget.dart';

/// Checkout confirmation screen.
///
/// Shows order summary and processes the sale.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Order summary
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Items section
                    _buildSectionHeader(theme, 'Order Items'),
                    const SizedBox(height: 8),
                    _buildItemsList(theme, cart),

                    const SizedBox(height: 24),

                    // Payment summary
                    _buildSectionHeader(theme, 'Payment Summary'),
                    const SizedBox(height: 8),
                    _buildPaymentSummary(theme, cart),

                    const SizedBox(height: 24),

                    // Payment details
                    _buildSectionHeader(theme, 'Payment Details'),
                    const SizedBox(height: 8),
                    _buildPaymentDetails(theme, cart),

                    // Error message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorMessage(theme),
                    ],
                  ],
                ),
              ),
            ),

            // Confirm button
            _buildConfirmButton(theme, cart),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Colors.grey[700],
      ),
    );
  }

  Widget _buildItemsList(ThemeData theme, CartState cart) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(color: Colors.grey[200]!),
                      ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quantity badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '×${item.quantity}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Item details
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
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        if (item.hasDiscount)
                          Text(
                            cart.isPercentageDiscount
                                ? '${item.discountValue.toStringAsFixed(0)}% off'
                                : '${AppConstants.currencySymbol}${item.discountValue.toStringAsFixed(2)} off',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green[700],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Amount
                  Text(
                    '${AppConstants.currencySymbol}${netAmount.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            theme,
            'Subtotal',
            '${AppConstants.currencySymbol}${cart.subtotal.toStringAsFixed(2)}',
          ),
          if (cart.hasDiscount) ...[
            const SizedBox(height: 8),
            _buildSummaryRow(
              theme,
              'Discount',
              '-${AppConstants.currencySymbol}${cart.totalDiscount.toStringAsFixed(2)}',
              valueColor: Colors.green,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          _buildSummaryRow(
            theme,
            'Total',
            '${AppConstants.currencySymbol}${cart.grandTotal.toStringAsFixed(2)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetails(ThemeData theme, CartState cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            theme,
            Icons.payment,
            'Payment Method',
            cart.paymentMethod == PaymentMethod.cash ? 'Cash' : 'GCash',
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            theme,
            Icons.account_balance_wallet,
            'Amount Received',
            '${AppConstants.currencySymbol}${cart.amountReceived.toStringAsFixed(2)}',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          _buildDetailRow(
            theme,
            Icons.change_circle,
            'Change',
            '${AppConstants.currencySymbol}${cart.change.toStringAsFixed(2)}',
            valueStyle: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
        ],
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
                  ?.copyWith(fontWeight: FontWeight.bold)
              : theme.textTheme.bodyMedium,
        ),
        Text(
          value,
          style: isTotal
              ? theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
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

  Widget _buildDetailRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value, {
    TextStyle? valueStyle,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          value,
          style: valueStyle ??
              theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton(ThemeData theme, CartState cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isProcessing ? null : () => _processCheckout(cart),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
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
                      const Icon(Icons.check_circle, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Confirm Payment • ${AppConstants.currencySymbol}${cart.grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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

      // Create the use case
      final useCase = ProcessSaleUseCase(
        saleRepository: ref.read(saleRepositoryProvider),
        productRepository: ref.read(productRepositoryProvider),
        draftRepository: ref.read(draftRepositoryProvider),
      );

      // Build sale entity from cart
      final cartNotifier = ref.read(cartProvider.notifier);
      final sale = cartNotifier.toSale(
        saleNumber: '', // Will be generated by use case
        cashierId: currentUser.id,
        cashierName: currentUser.displayName,
      );

      // Process the sale
      final result = await useCase.execute(sale: sale);

      if (result.success && result.sale != null) {
        // Reset cart
        cartNotifier.resetAfterCheckout();

        // Clear selected draft
        ref.read(selectedDraftProvider.notifier).state = null;

        // Invalidate providers to refresh data
        ref.invalidate(todaysSalesProvider);
        ref.invalidate(todaysSalesSummaryProvider);
        ref.invalidate(activeDraftsProvider);
        ref.invalidate(productsProvider);
        ref.invalidate(lowStockProductsProvider);

        if (mounted) {
          // Show success dialog
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
    // Show receipt in a bottom sheet
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
