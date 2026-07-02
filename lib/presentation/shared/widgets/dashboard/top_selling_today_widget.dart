import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/top_selling.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/dashboard_list_card.dart';

/// Top Selling Items Today on the mobile admin dashboard.
///
/// Default view shows the top 5 ranked rows. A "See more" toggle expands
/// the list inline to show ranks 6–10 (and collapses back). When fewer
/// than 6 products have been sold, the toggle is hidden — there's
/// nothing to expand to.
class TopSellingTodayWidget extends ConsumerStatefulWidget {
  /// Number of rows shown in the collapsed state.
  final int collapsedLimit;

  /// Maximum number of rows shown when expanded.
  final int expandedLimit;

  const TopSellingTodayWidget({
    super.key,
    this.collapsedLimit = 5,
    this.expandedLimit = 10,
  });

  @override
  ConsumerState<TopSellingTodayWidget> createState() =>
      _TopSellingTodayWidgetState();
}

class _TopSellingTodayWidgetState
    extends ConsumerState<TopSellingTodayWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final rankedAsync = ref.watch(topSellingTodayProvider);

    return rankedAsync.when(
      data: (ranked) {
        if (ranked.isEmpty) {
          return _EmptyState(muted: muted);
        }

        final limit = _expanded ? widget.expandedLimit : widget.collapsedLimit;
        final visible = ranked.take(limit).toList();
        final canExpand = ranked.length > widget.collapsedLimit;
        final divider = Divider(
          height: 1,
          thickness: 1,
          indent: 14,
          endIndent: 14,
          // Hairline grey — the theme dividerColor reads too dark between
          // these rows.
          color: AppColors.hairline(theme.brightness == Brightness.dark),
        );

        return DashboardListCard(
          child: Column(
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) divider,
                _Row(item: visible[i]),
              ],
              if (canExpand) ...[
                divider,
                TextButton.icon(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 16,
                  ),
                  label: Text(_expanded ? 'See less' : 'See more'),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          'Error loading top sellers: $error',
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final TopSellingItem item;

  const _Row({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const _Thumb(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: AppTextStyles.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.quantitySold} sold',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.totalRevenue.toCurrency(),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 40×40 product thumbnail placeholder (radius 11). Wire to real product
/// images later; for now a quiet tile with a package glyph.
class _Thumb extends StatelessWidget {
  const _Thumb();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkHairline : AppColors.lightCanvas,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isDark ? AppColors.darkHairline : AppColors.lightHairline,
        ),
      ),
      child: Icon(
        LucideIcons.package,
        size: 18,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color muted;

  const _EmptyState({required this.muted});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DashboardListCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.shoppingCart, size: 36, color: muted),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No products sold yet today',
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
