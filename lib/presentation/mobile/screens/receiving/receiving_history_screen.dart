import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Full list of completed receivings.
class ReceivingHistoryScreen extends ConsumerWidget {
  const ReceivingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receivingsAsync = ref.watch(recentReceivingsProvider);
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.receiving),
        ),
        title: const Text('Receiving History'),
      ),
      body: receivingsAsync.when(
        data: (receivings) {
          final completed = receivings
              .where((r) => r.status == ReceivingStatus.completed)
              .toList();

          if (completed.isEmpty) {
            return const EmptyStateView(
              icon: CupertinoIcons.cube_box,
              title: 'No Receiving History',
              subtitle: 'Completed receivings will appear here',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: completed.length,
            itemBuilder: (context, index) => _ReceivingHistoryItem(
                receiving: completed[index], dateFormat: dateFormat),
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorStateView(
          message: 'Error: $error',
          onRetry: () => ref.invalidate(recentReceivingsProvider),
        ),
      ),
    );
  }
}

class _ReceivingHistoryItem extends StatelessWidget {
  final ReceivingEntity receiving;
  final DateFormat dateFormat;

  const _ReceivingHistoryItem({
    required this.receiving,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              Icon(CupertinoIcons.checkmark_circle, color: Colors.green[700]),
        ),
        title: Text(
          receiving.referenceNumber,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateFormat.format(receiving.completedAt ?? receiving.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (receiving.supplierName != null)
              Text(
                receiving.supplierName!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${receiving.totalQuantity} items',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${AppConstants.currencySymbol}${receiving.totalCost.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        onTap: () =>
            context.push('${RoutePaths.bulkReceiving}/${receiving.id}'),
      ),
    );
  }
}
