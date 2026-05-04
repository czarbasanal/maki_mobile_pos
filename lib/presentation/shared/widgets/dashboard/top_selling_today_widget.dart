import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/top_selling.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';

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

        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: [
                for (var i = 0; i < visible.length; i++)
                  _Row(
                    rank: i + 1,
                    item: visible[i],
                  ),
                if (canExpand)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _expanded = !_expanded),
                      icon: Icon(
                        _expanded
                            ? CupertinoIcons.chevron_up
                            : CupertinoIcons.chevron_down,
                        size: 16,
                      ),
                      label: Text(_expanded ? 'See less' : 'See more'),
                    ),
                  ),
              ],
            ),
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
  final int rank;
  final TopSellingItem item;

  const _Row({required this.rank, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.sku,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.quantitySold} sold',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${AppConstants.currencySymbol}${item.totalRevenue.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ],
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.cart, size: 36, color: muted),
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
