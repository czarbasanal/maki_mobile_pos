import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:intl/intl.dart';

/// Widget displaying a printable receipt.
///
/// The outer modal wraps the airy theme (hairline handle, themed
/// dividers); the receipt body itself stays paper-like — white
/// background, dashed dividers, monochrome — because it represents
/// a printable artifact and benefits from looking that way.
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
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Column(
        children: [
          // Drag handle — hairline color, theme-aware
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.sm + 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: hairline,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Text(
                  'Receipt',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (onShare != null)
                  IconButton(
                    icon: const Icon(CupertinoIcons.share),
                    onPressed: onShare,
                    tooltip: 'Share',
                  ),
                if (onPrint != null)
                  IconButton(
                    icon: const Icon(CupertinoIcons.printer),
                    onPressed: onPrint,
                    tooltip: 'Print',
                  ),
                IconButton(
                  icon: const Icon(CupertinoIcons.xmark),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Receipt body — paper-like, white background, hairline border
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.lightHairline),
                ),
                child: Column(
                  children: [
                    _buildStoreHeader(theme),
                    const SizedBox(height: AppSpacing.md),
                    _buildDottedDivider(),
                    const SizedBox(height: AppSpacing.md),
                    _buildTransactionInfo(theme, dateFormat),
                    const SizedBox(height: AppSpacing.md),
                    _buildDottedDivider(),
                    const SizedBox(height: AppSpacing.md),
                    _buildItemsSection(theme),
                    const SizedBox(height: AppSpacing.md),
                    _buildDottedDivider(),
                    const SizedBox(height: AppSpacing.md),
                    _buildTotalsSection(theme),
                    const SizedBox(height: AppSpacing.md),
                    _buildDottedDivider(),
                    const SizedBox(height: AppSpacing.md),
                    _buildPaymentSection(theme),
                    const SizedBox(height: AppSpacing.lg),
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
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.store_outlined,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        Text(
          AppConstants.appName,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black, // Receipt body forces black text on white
          ),
        ),
        const Text(
          'Official Receipt',
          style: TextStyle(
            fontSize: 12,
            color: _ReceiptColors.label,
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
          style: const TextStyle(color: _ReceiptColors.label, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                'Item',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.black,
                ),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                'Qty',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.black,
                ),
              ),
            ),
            SizedBox(
              width: 70,
              child: Text(
                'Amount',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...sale.items.map((item) {
          final netAmount = item.calculateNetAmount(
            isPercentage: sale.isPercentageDiscount,
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            '@${AppConstants.currencySymbol}${item.unitPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: _ReceiptColors.label,
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        '${AppConstants.currencySymbol}${netAmount.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                        ),
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
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.successDark,
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
        const SizedBox(height: AppSpacing.sm),
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
            fontWeight: isGrandTotal ? FontWeight.w600 : FontWeight.normal,
            fontSize: isGrandTotal ? 16 : 12,
            color: Colors.black,
          ),
        ),
        Text(
          '${isDiscount ? '-' : ''}${AppConstants.currencySymbol}${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: isGrandTotal ? FontWeight.w600 : FontWeight.w500,
            fontSize: isGrandTotal ? 16 : 12,
            color: isDiscount ? AppColors.successDark : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.lightHairline),
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
            fontWeight: isChange ? FontWeight.w600 : FontWeight.normal,
            fontSize: isChange ? 14 : 12,
            color: Colors.black,
          ),
        ),
        Text(
          '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isChange ? 18 : 12,
            color: isChange ? AppColors.successDark : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Column(
      children: [
        const Text(
          'Thank you for your purchase!',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Please come again',
          style: TextStyle(
            fontSize: 12,
            color: _ReceiptColors.label,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.lightHairline),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Icon(
            CupertinoIcons.qrcode,
            size: 60,
            color: _ReceiptColors.label,
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
            color:
                index.isOdd ? Colors.transparent : AppColors.lightHairline,
          ),
        ),
      ),
    );
  }
}

/// Hard-coded receipt-body greys. The receipt is always rendered on a
/// white paper background regardless of theme, so theme-aware tokens
/// would be wrong here.
abstract class _ReceiptColors {
  static const Color label = Color(0xFF666666);
}
