import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Today's Sales section for the dashboard.
///
/// Hierarchy (per the refreshed theme): the **Gross Sales** figure is the hero
/// — a large lifted card where the number dominates. Admins get a supporting
/// 3-up stat grid below (Avg Daily / COGS / Profit) plus a Service/Labor card
/// when labor revenue exists. Cashiers and staff see only the hero.
class SalesSummarySection extends ConsumerWidget {
  /// When true, shows the admin-only supporting stats below the hero.
  final bool isAdmin;

  const SalesSummarySection({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(todaysSalesSummaryProvider);
    final avgDailyAsync = ref.watch(avgDailySalesProvider);

    return summaryAsync.when(
      data: (summary) {
        final avgDaily = avgDailyAsync.valueOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GrossHeroCard(summary: summary),
            if (isAdmin) ...[
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: LucideIcons.barChart3,
                        label: 'Avg Daily',
                        value: avgDaily != null
                            ? _money(avgDaily, compact: true)
                            : '—',
                        onInfo: () => _showAvgDailyInfo(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: LucideIcons.boxes,
                        label: 'COGS',
                        value: _money(summary.totalCost, compact: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: LucideIcons.trendingUp,
                        label: 'Profit',
                        value: _money(summary.totalProfit, compact: true),
                        iconColor: _profitGreen(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Labor and shop fees pair up on one row when both are earning
              // today; whichever appears alone keeps the full width.
              // Shop fees have zero cost (like labor), so revenue == profit.
              if (summary.laborRevenue > 0 || summary.feesRevenue > 0) ...[
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  final labor = summary.laborRevenue > 0
                      ? _StatCard(
                          icon: LucideIcons.wrench,
                          label: 'Service / Labor',
                          value: _money(summary.laborRevenue),
                          subtitle: '${_money(summary.laborProfit)} profit',
                        )
                      : null;
                  final fees = summary.feesRevenue > 0
                      ? _StatCard(
                          icon: LucideIcons.receipt,
                          label: 'Shop Fees',
                          value: _money(summary.feesRevenue),
                          subtitle: '${_money(summary.feesRevenue)} profit',
                        )
                      : null;
                  if (labor != null && fees != null) {
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: labor),
                          const SizedBox(width: 10),
                          Expanded(child: fees),
                        ],
                      ),
                    );
                  }
                  return labor ?? fees!;
                }),
              ],
            ],
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Center(
        child: Text('Error loading summary: $error'),
      ),
    );
  }
}

/// The Gross Sales hero — the page's primary metric. Lifted card (radius 22,
/// hero shadow) where the value is rendered large with the centavos sitting
/// smaller and muted beside it.
class _GrossHeroCard extends StatelessWidget {
  final SalesSummary summary;

  const _GrossHeroCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;

    // Split into whole + centavos so the decimals can sit smaller/muted.
    final parts = summary.grossAmount.toStringAsFixed(2).split('.');
    final whole = NumberFormat('#,##0').format(int.parse(parts[0]));
    final cents = parts[1];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        border: isDark ? Border.all(color: AppColors.darkHairline) : null,
        boxShadow: AppShadows.hero(dark: isDark),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.wallet, size: 18, color: muted),
              const SizedBox(width: 8),
              Text(
                'Gross Sales',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${AppConstants.currencySymbol}$whole',
                  style: TextStyle(
                    fontSize: 38,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  '.$cents',
                  style: TextStyle(
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _heroSubtitle(summary),
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }

  String _heroSubtitle(SalesSummary s) {
    final count = s.totalSalesCount;
    final sales = '$count ${count == 1 ? 'sale' : 'sales'}';
    if (s.totalDiscounts > 0) {
      return '${_money(s.totalDiscounts)} discount applied · $sales';
    }
    return sales;
  }
}

/// Compact supporting stat card (radius 16). Light: soft card shadow; dark:
/// 1px border. The value (18/700) leads; the icon and label stay quiet.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final String? subtitle;

  /// When supplied, a small ⓘ sits opposite the leading icon; tapping it is
  /// how the metric explains itself. Only cards whose meaning isn't obvious
  /// from the label pass this.
  final VoidCallback? onInfo;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.subtitle,
    this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: isDark ? Border.all(color: AppColors.darkHairline) : null,
        boxShadow: AppShadows.card(dark: isDark),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      // A Stack, not a bare Column: the info hit region below is a
      // `Positioned` child, and Positioned children are excluded from a
      // Stack's own size computation — so it can genuinely report a
      // larger tappable box (unlike the previous OverflowBox attempt,
      // whose own `hitTest` was still gated on its small parent size)
      // without the card growing even a pixel. Only the Column below
      // determines this Stack's — and therefore the card's — height.
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: iconColor ?? muted),
              const SizedBox(height: 10),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: muted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ],
            ],
          ),
          if (onInfo != null)
            // Real 48x48 tap target (Material's minimum) anchored on the
            // same top-right corner the old 18x18 box occupied. None of
            // the card's content is interactive, so the region overlapping
            // the label below steals no other tap. The glyph itself stays
            // pinned to the top-right (matching where it used to sit,
            // level with the leading icon) rather than centred in the
            // full 48px box, so it doesn't visibly drift downward.
            Positioned(
              top: 0,
              right: 0,
              width: 48,
              height: 48,
              child: InkWell(
                onTap: onInfo,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, right: 2),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Icon(LucideIcons.info, size: 14, color: muted),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Profit-positive green (theme-aware) for the Profit stat icon.
Color _profitGreen(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF5FC86A)
        : const Color(0xFF4CAF50);

/// `₱1,234.56`, or compact `₱9.8K` / `₱1.2M` for the tight stat cards.
String _money(double value, {bool compact = false}) {
  final symbol = AppConstants.currencySymbol;
  if (compact) {
    if (value >= 1000000) return '$symbol${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '$symbol${(value / 1000).toStringAsFixed(1)}K';
    return '$symbol${value.toStringAsFixed(0)}';
  }
  return '$symbol${NumberFormat('#,##0.00').format(value)}';
}

/// Explains what the Avg Daily figure actually averages. Tap-to-open rather
/// than a long-press tooltip — a tooltip is undiscoverable on a phone.
void _showAvgDailyInfo(BuildContext context) {
  final theme = Theme.of(context);
  showDialog<void>(
    context: context,
    barrierColor:
        AppDialog.scrimColor(theme.brightness == Brightness.dark),
    builder: (context) => AppDialog(
      title: 'Avg Daily',
      leadingIcon: LucideIcons.barChart3,
      onClose: () => Navigator.of(context).pop(),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Your average sales per day this month, counting only days that '
            'have finished.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 12),
          Text(
            "It adds up sales from the 1st up to yesterday, then divides by "
            "that many days. Today isn't counted yet because it's still "
            "going.",
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.45,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
