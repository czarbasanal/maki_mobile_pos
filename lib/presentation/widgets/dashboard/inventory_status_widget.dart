import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/widgets/dashboard/summary_card.dart';

/// Widget displaying inventory status summary.
class InventoryStatusWidget extends ConsumerWidget {
  const InventoryStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(inventorySummaryProvider);

    return summaryAsync.when(
      data: (summary) {
        return Row(
          children: [
            Expanded(
              child: SummaryCard(
                title: 'Total',
                value: '${summary.totalProducts}',
                icon: Icons.inventory_2,
                iconColor: Colors.blue,
                compact: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SummaryCard(
                title: 'In Stock',
                value: '${summary.inStockCount}',
                icon: Icons.check_circle,
                iconColor: Colors.green,
                compact: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SummaryCard(
                title: 'Low',
                value: '${summary.lowStockCount}',
                icon: Icons.warning,
                iconColor: Colors.orange,
                compact: true,
                highlighted: summary.lowStockCount > 0,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SummaryCard(
                title: 'Out',
                value: '${summary.outOfStockCount}',
                icon: Icons.error,
                iconColor: Colors.red,
                compact: true,
                highlighted: summary.outOfStockCount > 0,
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
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error: $error',
            style: TextStyle(color: Colors.red[700]),
          ),
        ),
      ),
    );
  }
}
