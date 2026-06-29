import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

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

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.barChart3,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 9),
              Text(
                'Sales Summary',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Total Sales / Voided
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Total Sales',
                    value: '${summary.totalSalesCount}',
                    icon: LucideIcons.fileText,
                    valueSize: 17,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    label: 'Voided',
                    value: '${summary.voidedSalesCount}',
                    icon: LucideIcons.xCircle,
                    valueSize: 17,
                    accent: summary.voidedSalesCount > 0
                        ? AppColors.error
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Gross / Discounts
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Gross Sales',
                    value: summary.grossAmount.toCurrency(),
                    icon: LucideIcons.banknote,
                    subtitle: 'Before discounts',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    label: 'Discounts',
                    value: '-${summary.totalDiscounts.toCurrency()}',
                    icon: LucideIcons.tag,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Net Sales — tinted accent panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.emphasisTint(isDark),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net Sales',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  summary.netAmount.toCurrency(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    letterSpacing: -0.3,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          // ==================== ADMIN-ONLY SECTION ====================
          if (isAdmin) ...[
            // Admin-only divider
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 15, 0, 13),
              child: Row(
                children: [
                  Expanded(
                      child: Divider(
                          height: 1, color: AppColors.hairline(isDark))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.lock,
                            size: 11, color: theme.colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          'ADMIN ONLY',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                      child: Divider(
                          height: 1, color: AppColors.hairline(isDark))),
                ],
              ),
            ),
            // Average sale value
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(LucideIcons.divide, size: 14, color: muted),
                  const SizedBox(width: 6),
                  Text(
                    'Average sale value',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: muted, fontSize: 11.5),
                  ),
                  const Spacer(),
                  Text(
                    summary.averageSaleAmount.toCurrency(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Total Cost',
                      value: summary.totalCost.toCurrency(),
                      icon: LucideIcons.package,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      label: 'Gross Profit',
                      value: summary.totalProfit.toCurrency(),
                      icon: LucideIcons.trendingUp,
                      accent: AppColors.success,
                      subtitle:
                          '${summary.profitMargin.toStringAsFixed(1)}% margin',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Service Rev.',
                      value: summary.laborRevenue.toCurrency(),
                      icon: LucideIcons.wrench,
                      subtitle: 'Labor · no COGS',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      label: 'Service Profit',
                      value: summary.laborProfit.toCurrency(),
                      icon: LucideIcons.trendingUp,
                      accent: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Cashier / staff: cost & profit gated.
            Padding(
              padding: const EdgeInsets.only(top: 13),
              child: Row(
                children: [
                  Icon(LucideIcons.lock, size: 13, color: muted),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      'Cost & profit are hidden for your role',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: muted, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const AppCard(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Failed to load summary',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ],
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
    this.valueSize = 15,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accent;
  final String? subtitle;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = accent ?? AppColors.hairline(isDark);
    final labelColor = accent ?? muted;
    final valueColor = accent != null
        ? (accent == AppColors.success
            ? AppColors.successText(isDark)
            : accent!)
        : theme.colorScheme.onSurface;
    final subColor =
        accent == AppColors.success ? AppColors.successText(isDark) : muted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent ?? muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: valueSize,
              color: valueColor,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: subColor,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
