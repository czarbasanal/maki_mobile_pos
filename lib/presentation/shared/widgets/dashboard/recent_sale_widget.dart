import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Widget displaying recent sales transactions.
class RecentSalesWidget extends ConsumerWidget {
  final int limit;

  const RecentSalesWidget({
    super.key,
    this.limit = 5,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(todaysSalesProvider);

    return salesAsync.when(
      data: (sales) {
        if (sales.isEmpty) {
          return _buildEmptyState();
        }

        final recentSales = sales.take(limit).toList();
        return Column(
          children:
              recentSales.map((sale) => _RecentSaleItem(sale: sale)).toList(),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error loading sales: $error',
            style: TextStyle(color: Colors.red[700]),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'No recent transactions',
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSaleItem extends StatelessWidget {
  final SaleEntity sale;

  const _RecentSaleItem({required this.sale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('h:mm a');
    final isVoided = sale.status == SaleStatus.voided;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isVoided
                ? Colors.red.withOpacity(0.1)
                : _getPaymentColor(sale.paymentMethod).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isVoided ? Icons.cancel : _getPaymentIcon(sale.paymentMethod),
            color: isVoided ? Colors.red : _getPaymentColor(sale.paymentMethod),
          ),
        ),
        title: Row(
          children: [
            Text(
              sale.saleNumber,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: isVoided ? TextDecoration.lineThrough : null,
              ),
            ),
            if (isVoided) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'VOID',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${sale.totalItemCount} items • ${timeFormat.format(sale.createdAt)}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Text(
          '${AppConstants.currencySymbol}${sale.grandTotal.toStringAsFixed(2)}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isVoided ? Colors.grey : theme.colorScheme.primary,
            decoration: isVoided ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }

  IconData _getPaymentIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.payments;
      case PaymentMethod.gcash:
        return Icons.phone_android;
    }
  }

  Color _getPaymentColor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Colors.green;
      case PaymentMethod.gcash:
        return Colors.blue;
    }
  }
}
