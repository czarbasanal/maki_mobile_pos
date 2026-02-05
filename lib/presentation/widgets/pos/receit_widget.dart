import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:intl/intl.dart';

/// Widget displaying a printable receipt.
class ReceiptWidget extends StatelessWidget {
  final SaleEntity sale;
  final ScrollController? scrollController;
  final VoidCallback? onPrint;
  final VoidCallback? onShare;

  const ReceiptWidget({
    super.key,
    required this.sale,
    this.scrollController,
    this.onPrint,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Receipt',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (onShare != null)
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: onShare,
                    tooltip: 'Share',
                  ),
                if (onPrint != null)
                  IconButton(
                    icon: const Icon(Icons.print),
                    onPressed: onPrint,
                    tooltip: 'Print',
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Receipt content
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Store header
                    _buildStoreHeader(theme),

                    const SizedBox(height: 16),
                    _buildDottedDivider(),
                    const SizedBox(height: 16),

                    // Transaction info
                    _buildTransactionInfo(theme, dateFormat),

                    const SizedBox(height: 16),
                    _buildDottedDivider(),
                    const SizedBox(height: 16),

                    // Items
                    _buildItemsSection(theme),

                    const SizedBox(height: 16),
                    _buildDottedDivider(),
                    const SizedBox(height: 16),

                    // Totals
                    _buildTotalsSection(theme),

                    const SizedBox(height: 16),
                    _buildDottedDivider(),
                    const SizedBox(height: 16),

                    // Payment info
                    _buildPaymentSection(theme),

                    const SizedBox(height: 24),

                    // Footer
                    _buildFooter(theme),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreHeader(ThemeData theme) {
    return Column(
      children: [
        // Store logo placeholder
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.store,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppConstants.appName,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Official Receipt',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionInfo(ThemeData theme, DateFormat dateFormat) {
    return Column(
      children: [
        _buildInfoRow('Receipt #', sale.saleNumber),
        const SizedBox(height: 4),
        _buildInfoRow('Date', dateFormat.format(sale.createdAt)),
        const SizedBox(height: 4),
        _buildInfoRow('Cashier', sale.cashierName),
        if (sale.paymentMethod.displayName.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildInfoRow('Payment', sale.paymentMethod.displayName),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Expanded(
              flex: 3,
              child: Text(
                'Item',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(
              width: 40,
              child: Text(
                'Qty',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(
              width: 70,
              child: Text(
                'Amount',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Items
        ...sale.items.map((item) {
          final netAmount = item.calculateNetAmount(
            isPercentage: sale.isPercentageDiscount,
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '@${AppConstants.currencySymbol}${item.unitPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${item.quantity}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        '${AppConstants.currencySymbol}${netAmount.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                if (item.hasDiscount)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      sale.isPercentageDiscount
                          ? '  Discount: ${item.discountValue.toStringAsFixed(0)}%'
                          : '  Discount: -${AppConstants.currencySymbol}${item.discountValue.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTotalsSection(ThemeData theme) {
    return Column(
      children: [
        _buildTotalRow('Subtotal', sale.subtotal),
        if (sale.hasDiscount) ...[
          const SizedBox(height: 4),
          _buildTotalRow('Discount', -sale.totalDiscount, isDiscount: true),
        ],
        const SizedBox(height: 8),
        _buildTotalRow('TOTAL', sale.grandTotal, isGrandTotal: true),
      ],
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount, {
    bool isDiscount = false,
    bool isGrandTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isGrandTotal ? 16 : 12,
          ),
        ),
        Text(
          '${isDiscount ? '-' : ''}${AppConstants.currencySymbol}${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.w500,
            fontSize: isGrandTotal ? 16 : 12,
            color: isDiscount ? Colors.green[700] : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildPaymentRow('Amount Tendered', sale.amountReceived),
          const SizedBox(height: 4),
          _buildPaymentRow('Change', sale.changeGiven, isChange: true),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, double amount,
      {bool isChange = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isChange ? FontWeight.bold : FontWeight.normal,
            fontSize: isChange ? 14 : 12,
          ),
        ),
        Text(
          '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isChange ? 18 : 12,
            color: isChange ? Colors.green[700] : null,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Column(
      children: [
        Text(
          'Thank you for your purchase!',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Please come again',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        // QR code placeholder
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Icons.qr_code,
            size: 60,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildDottedDivider() {
    return Row(
      children: List.generate(
        50,
        (index) => Expanded(
          child: Container(
            height: 1,
            color: index.isOdd ? Colors.transparent : Colors.grey[300],
          ),
        ),
      ),
    );
  }
}
