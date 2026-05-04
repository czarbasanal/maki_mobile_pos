import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/string_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
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
          return const _EmptyState();
        }

        final recentSales = sales.take(limit).toList();
        return Column(
          children: [
            for (var i = 0; i < recentSales.length; i++) ...[
              _RecentSaleItem(sale: recentSales[i]),
              if (i < recentSales.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Error loading sales: $error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.doc_text, size: 36, color: muted),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No recent transactions',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
    final muted = theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          isVoided
              ? CupertinoIcons.xmark_circle
              : _paymentIcon(sale.paymentMethod),
          color: isVoided ? AppColors.error : muted,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                sale.saleNumber,
                style: AppTextStyles.productName.copyWith(
                  decoration: isVoided ? TextDecoration.lineThrough : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isVoided) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.error),
                ),
                child: const Text(
                  'VOID',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          _subtitle(sale, timeFormat),
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        trailing: Text(
          '${AppConstants.currencySymbol}${sale.grandTotal.toStringAsFixed(2)}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isVoided ? muted : null,
            decoration: isVoided ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }

  IconData _paymentIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return AppIcons.peso;
      case PaymentMethod.maya:
        return CupertinoIcons.creditcard;
      case PaymentMethod.gcash:
        return CupertinoIcons.device_phone_portrait;
    }
  }

  /// Subtitle reads "Alice • 3 items • 2:35 PM". The cashier first name
  /// leads so the operator sees who handled the transaction at a glance;
  /// it's omitted entirely when the snapshot has no name.
  String _subtitle(SaleEntity sale, DateFormat timeFormat) {
    final cashierFirst = sale.cashierName.firstName;
    final tail = '${sale.totalItemCount} items • ${timeFormat.format(sale.createdAt)}';
    return cashierFirst.isEmpty ? tail : '$cashierFirst • $tail';
  }
}
