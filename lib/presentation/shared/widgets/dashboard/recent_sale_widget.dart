import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/dashboard_list_card.dart';

/// Widget displaying recent sales transactions in a single elevated list card,
/// rows separated by hairlines (per the refreshed theme).
class RecentSalesWidget extends ConsumerWidget {
  final int limit;

  const RecentSalesWidget({
    super.key,
    this.limit = 5,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(todaysSalesProvider);
    final theme = Theme.of(context);

    return salesAsync.when(
      data: (sales) {
        if (sales.isEmpty) {
          return const _EmptyState();
        }

        final recentSales = sales.take(limit).toList();
        final divider = Divider(
          height: 1,
          thickness: 1,
          indent: 14,
          endIndent: 14,
          color: theme.dividerColor,
        );
        return DashboardListCard(
          child: Column(
            children: [
              for (var i = 0; i < recentSales.length; i++) ...[
                if (i > 0) divider,
                _RecentSaleItem(sale: recentSales[i]),
              ],
            ],
          ),
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
            style: TextStyle(color: theme.colorScheme.error),
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
    return DashboardListCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.receipt, size: 36, color: muted),
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

    return InkWell(
      onTap: () => context.push('${RoutePaths.reports}/sale/${sale.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          sale.saleNumber,
                          style: TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: theme.colorScheme.onSurface,
                            decoration: isVoided
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVoided) ...[
                        const SizedBox(width: AppSpacing.sm),
                        _VoidBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(sale, timeFormat),
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (!isVoided) ...[
              _PaymentChip(method: sale.paymentMethod),
              const SizedBox(width: 10),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 56),
              child: Text(
                '${AppConstants.currencySymbol}${sale.grandTotal.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isVoided ? muted : null,
                  decoration: isVoided ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Subtitle reads "9:32 AM · 3 items" (· "Alice" when the snapshot has a
  /// cashier name) — time leads so the operator scans the timeline.
  String _subtitle(SaleEntity sale, DateFormat timeFormat) {
    final time = timeFormat.format(sale.createdAt);
    final items = '${sale.totalItemCount} items';
    final cashierFirst = sale.cashierName.trim().split(RegExp(r'\s+')).first;
    final base = '$time · $items';
    return cashierFirst.isEmpty ? base : '$cashierFirst · $base';
  }
}

class _VoidBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    );
  }
}

/// Payment-method chip — cash/gcash carry their brand tints (per the handoff
/// token table); other methods fall back to a neutral chip.
class _PaymentChip extends StatelessWidget {
  final PaymentMethod method;

  const _PaymentChip({required this.method});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    late final Color bg;
    late final Color fg;
    switch (method) {
      case PaymentMethod.cash:
        bg = isDark ? const Color(0x2E4CAF50) : const Color(0xFFE8F5E9);
        fg = isDark ? const Color(0xFF8FE39A) : const Color(0xFF2E7D32);
        break;
      case PaymentMethod.gcash:
        bg = isDark ? const Color(0x33007DFE) : const Color(0xFFE3F0FF);
        fg = isDark ? const Color(0xFF7FB6FF) : const Color(0xFF024A99);
        break;
      case PaymentMethod.maya:
      case PaymentMethod.salmon:
      case PaymentMethod.mixed:
        bg = isDark ? AppColors.darkHairline : AppColors.lightCanvas;
        fg = theme.colorScheme.onSurfaceVariant;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        _label(method),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: fg,
        ),
      ),
    );
  }

  String _label(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'CASH';
      case PaymentMethod.gcash:
        return 'GCASH';
      case PaymentMethod.maya:
        return 'MAYA';
      case PaymentMethod.salmon:
        return 'SALMON';
      case PaymentMethod.mixed:
        return 'MIXED';
    }
  }
}
