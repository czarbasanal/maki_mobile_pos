import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/constants/constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Card displaying sales summary metrics.
///
/// Role-based visibility:
/// - All roles see: Total Sales, Voided count, Gross Sales, Discounts, Net Sales
/// - Admin only sees: Average Daily Sales, Total Cost, Gross Profit (+ margin %)
class SalesSummaryCard extends ConsumerWidget {
  final DateTime startDate;
  final DateTime endDate;

  const SalesSummaryCard({
    super.key,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = DateRangeParams(
      startDate: startDate,
      endDate: endDate,
    );

    final summaryAsync = ref.watch(salesSummaryProvider(params));
    final currentUser = ref.watch(currentUserProvider).value;
    final isAdmin = currentUser?.role == UserRole.admin;

    return summaryAsync.when(
      data: (summary) => _buildSummaryContent(context, summary, isAdmin),
      loading: () => _buildLoadingState(),
      error: (error, _) => _buildErrorState(context, error),
    );
  }

  Widget _buildSummaryContent(
      BuildContext context, SalesSummary summary, bool isAdmin) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              icon: CupertinoIcons.chart_bar,
              title: 'Sales Summary',
            ),
            const SizedBox(height: AppSpacing.lg - 4),
            // Main metrics — Total Sales / Voided
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Total Sales',
                      value: '${summary.totalSalesCount}',
                      icon: CupertinoIcons.doc_text,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: _MetricCard(
                      label: 'Voided',
                      value: '${summary.voidedSalesCount}',
                      icon: CupertinoIcons.xmark_circle,
                      accent: summary.voidedSalesCount > 0
                          ? AppColors.error
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            // Revenue metrics — Gross / Discounts
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Gross Sales',
                      value:
                          '${AppConstants.currencySymbol}${summary.grossAmount.toStringAsFixed(2)}',
                      icon: CupertinoIcons.money_dollar,
                      subtitle: 'Before discounts',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: _MetricCard(
                      label: 'Discounts',
                      value:
                          '-${AppConstants.currencySymbol}${summary.totalDiscounts.toStringAsFixed(2)}',
                      icon: CupertinoIcons.tag,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),
            // Net sales — outlined accent panel
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: theme.colorScheme.primary),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Net Sales',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${AppConstants.currencySymbol}${summary.netAmount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            // ==================== ADMIN-ONLY SECTION ====================
            if (isAdmin) ...[
              const SizedBox(height: AppSpacing.sm + 4),
              // Avg sale — outlined hairline pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 4,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: hairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.arrow_right, size: 14, color: muted),
                    const SizedBox(width: 4),
                    Text(
                      'Avg: ${AppConstants.currencySymbol}${summary.averageSaleAmount.toStringAsFixed(2)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Total Cost',
                        value:
                            '${AppConstants.currencySymbol}${summary.totalCost.toStringAsFixed(2)}',
                        icon: CupertinoIcons.cube_box,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: _MetricCard(
                        label: 'Gross Profit',
                        value:
                            '${AppConstants.currencySymbol}${summary.totalProfit.toStringAsFixed(2)}',
                        icon: CupertinoIcons.arrow_up_right,
                        accent: AppColors.success,
                        subtitle:
                            '${summary.profitMargin.toStringAsFixed(1)}% margin',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle,
              color: AppColors.error,
              size: 28,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Failed to load summary',
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Outlined metric card — neutral by default, semantic accent for status.
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accent;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final borderColor = accent ?? hairline;
    final textColor = accent ?? theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent ?? muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: muted,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 22),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
