import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/summary_card.dart';

/// Widget displaying inventory status summary.
///
/// Inventory state is colour-coded across all four cards — the
/// at-a-glance scannability is more valuable here than strict
/// monochrome discipline elsewhere. Low / Out also receive a status
/// border highlight when their count is non-zero.
class InventoryStatusWidget extends ConsumerWidget {
  const InventoryStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(inventorySummaryProvider);

    return summaryAsync.when(
      data: (summary) {
        final hasLow = summary.lowStockCount > 0;
        final hasOut = summary.outOfStockCount > 0;
        return Row(
          children: [
            Expanded(
              child: SummaryCard(
                title: 'Total',
                value: '${summary.totalProducts}',
                icon: CupertinoIcons.cube_box,
                iconColor: AppColors.info,
                compact: true,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: SummaryCard(
                title: 'In Stock',
                value: '${summary.inStockCount}',
                icon: CupertinoIcons.checkmark_circle,
                iconColor: AppColors.success,
                compact: true,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: SummaryCard(
                title: 'Low',
                value: '${summary.lowStockCount}',
                icon: CupertinoIcons.exclamationmark_triangle,
                iconColor: AppColors.warning,
                compact: true,
                highlighted: hasLow,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: SummaryCard(
                title: 'Out',
                value: '${summary.outOfStockCount}',
                icon: CupertinoIcons.exclamationmark_circle,
                iconColor: AppColors.error,
                compact: true,
                highlighted: hasOut,
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Error: $error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }
}
