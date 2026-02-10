import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/widgets/pos/receipt_widget.dart';
import 'package:maki_mobile_pos/presentation/widgets/pos/void_sale_dialog.dart';
import 'package:intl/intl.dart';

/// Screen displaying sale details with void option.
class SaleDetailScreen extends ConsumerWidget {
  final String saleId;

  const SaleDetailScreen({
    super.key,
    required this.saleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleAsync = ref.watch(saleByIdProvider(saleId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goBackOr(RoutePaths.reports),
        ),
        title: const Text('Sale Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'View Receipt',
            onPressed: () {
              final sale = saleAsync.valueOrNull;
              if (sale != null) {
                _showReceipt(context, sale);
              }
            },
          ),
        ],
      ),
      body: saleAsync.when(
        data: (sale) {
          if (sale == null) {
            return const Center(child: Text('Sale not found'));
          }
          return _buildSaleDetails(context, ref, sale);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildSaleDetails(
    BuildContext context,
    WidgetRef ref,
    SaleEntity sale,
  ) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEEE, MMMM d, y • h:mm a');
    final isVoided = sale.status == SaleStatus.voided;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status banner for voided sales
          if (isVoided) _buildVoidedBanner(theme, sale),

          // Sale header
          _buildSaleHeader(theme, sale, dateFormat),

          const SizedBox(height: 24),

          // Items section
          _buildSectionHeader(theme, 'Items'),
          const SizedBox(height: 8),
          _buildItemsList(theme, sale),

          const SizedBox(height: 24),

          // Payment section
          _buildSectionHeader(theme, 'Payment'),
          const SizedBox(height: 8),
          _buildPaymentCard(theme, sale),

          const SizedBox(height: 24),

          // Details section
          _buildSectionHeader(theme, 'Details'),
          const SizedBox(height: 8),
          _buildDetailsCard(theme, sale, dateFormat),

          // Void info for voided sales
          if (isVoided) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(theme, 'Void Information'),
            const SizedBox(height: 8),
            _buildVoidInfoCard(theme, sale, dateFormat),
          ],

          // Notes
          if (sale.notes != null && sale.notes!.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(theme, 'Notes'),
            const SizedBox(height: 8),
            _buildNotesCard(theme, sale),
          ],

          const SizedBox(height: 24),

          // Void button (only for non-voided sales)
          if (!isVoided) _buildVoidButton(context, ref, sale),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildVoidedBanner(ThemeData theme, SaleEntity sale) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.cancel, color: Colors.red[700], size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VOIDED',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (sale.voidReason != null)
                  Text(
                    sale.voidReason!,
                    style: TextStyle(
                      color: Colors.red[600],
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleHeader(
    ThemeData theme,
    SaleEntity sale,
    DateFormat dateFormat,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Sale number
          Text(
            sale.saleNumber,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Date
          Text(
            dateFormat.format(sale.createdAt),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          // Grand total
          Text(
            '${AppConstants.currencySymbol}${sale.grandTotal.toStringAsFixed(2)}',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: sale.status == SaleStatus.voided
                  ? Colors.grey
                  : theme.colorScheme.primary,
              decoration: sale.status == SaleStatus.voided
                  ? TextDecoration.lineThrough
                  : null,
            ),
          ),
          // Status badge
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color:
                  sale.status == SaleStatus.voided ? Colors.red : Colors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              sale.status.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
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

  Widget _buildItemsList(ThemeData theme, SaleEntity sale) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: sale.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == sale.items.length - 1;
          final netAmount = item.calculateNetAmount(
            isPercentage: sale.isPercentageDiscount,
          );

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        '${item.sku} • ${AppConstants.currencySymbol}${item.unitPrice.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      if (item.hasDiscount)
                        Text(
                          sale.isPercentageDiscount
                              ? '${item.discountValue.toStringAsFixed(0)}% discount'
                              : '${AppConstants.currencySymbol}${item.discountValue.toStringAsFixed(2)} discount',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green[700],
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${AppConstants.currencySymbol}${netAmount.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaymentCard(ThemeData theme, SaleEntity sale) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildPaymentRow(theme, 'Subtotal', sale.subtotal),
          if (sale.hasDiscount) ...[
            const SizedBox(height: 8),
            _buildPaymentRow(
              theme,
              'Discount',
              sale.totalDiscount,
              isDiscount: true,
            ),
          ],
          const Divider(height: 24),
          _buildPaymentRow(theme, 'Total', sale.grandTotal, isTotal: true),
          const Divider(height: 24),
          _buildPaymentRow(theme, 'Received', sale.amountReceived),
          const SizedBox(height: 8),
          _buildPaymentRow(theme, 'Change', sale.changeGiven, isChange: true),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(
    ThemeData theme,
    String label,
    double amount, {
    bool isDiscount = false,
    bool isTotal = false,
    bool isChange = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
        Text(
          '${isDiscount ? '-' : ''}${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isTotal || isChange ? FontWeight.bold : FontWeight.w500,
            fontSize: isTotal ? 18 : (isChange ? 16 : 14),
            color: isDiscount
                ? Colors.green[700]
                : isChange
                    ? Colors.green[700]
                    : isTotal
                        ? theme.colorScheme.primary
                        : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsCard(
    ThemeData theme,
    SaleEntity sale,
    DateFormat dateFormat,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            theme,
            Icons.person_outline,
            'Cashier',
            sale.cashierName,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            theme,
            Icons.payment,
            'Payment Method',
            sale.paymentMethod.displayName,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            theme,
            Icons.shopping_bag_outlined,
            'Items',
            '${sale.totalItemCount} (${sale.uniqueProductCount} products)',
          ),
          if (sale.draftId != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              theme,
              Icons.drafts_outlined,
              'From Draft',
              'Yes',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVoidInfoCard(
    ThemeData theme,
    SaleEntity sale,
    DateFormat dateFormat,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            theme,
            Icons.person_outline,
            'Voided by',
            sale.voidedByName ?? 'Unknown',
          ),
          if (sale.voidedAt != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              theme,
              Icons.access_time,
              'Voided at',
              dateFormat.format(sale.voidedAt!),
            ),
          ],
          if (sale.voidReason != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.note_outlined, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reason',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sale.voidReason!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesCard(ThemeData theme, SaleEntity sale) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sticky_note_2_outlined,
                  size: 16, color: Colors.amber[700]),
              const SizedBox(width: 8),
              Text(
                'Notes',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.amber[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(sale.notes!),
        ],
      ),
    );
  }

  Widget _buildVoidButton(
    BuildContext context,
    WidgetRef ref,
    SaleEntity sale,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _handleVoid(context, ref, sale),
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('Void This Sale'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  void _handleVoid(
    BuildContext context,
    WidgetRef ref,
    SaleEntity sale,
  ) {
    VoidSaleDialog.show(
      context: context,
      sale: sale,
      onVoided: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale voided successfully'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(saleByIdProvider(saleId));
      },
    );
  }

  void _showReceipt(BuildContext context, SaleEntity sale) {
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
        ),
      ),
    );
  }
}
