import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
import 'package:intl/intl.dart';

/// Main receiving screen showing history and entry point for new receivings.
class ReceivingScreen extends ConsumerWidget {
  const ReceivingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receivingsAsync = ref.watch(recentReceivingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Receiving'),
      ),
      body: Column(
        children: [
          // Summary cards
          _buildSummaryCards(context, ref),

          // Recent receivings
          Expanded(
            child: receivingsAsync.when(
              data: (receivings) =>
                  _buildReceivingsList(context, ref, receivings),
              loading: () => const LoadingView(),
              error: (error, _) => ErrorStateView(
                message: 'Error: $error',
                onRetry: () => ref.invalidate(recentReceivingsProvider),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _startNewReceiving(context, ref),
            icon: const Icon(CupertinoIcons.add),
            label: const Text('New Receiving'),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(receivingCountsProvider);
    final mtdCount = ref.watch(monthToDateCompletedReceivingsProvider);

    return countsAsync.when(
      data: (counts) => Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildCountCard(
                'Drafts',
                '${counts[ReceivingStatus.draft] ?? 0}',
                CupertinoIcons.square_pencil,
                Colors.orange,
                onTap: () => context.push(RoutePaths.receivingDrafts),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCountCard(
                'Completed',
                '${counts[ReceivingStatus.completed] ?? 0}',
                CupertinoIcons.checkmark_circle,
                Colors.green,
                onTap: () => context.push(RoutePaths.receivingHistory),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCountCard(
                'This Month',
                '${mtdCount.valueOrNull ?? 0}',
                CupertinoIcons.calendar,
                Colors.blue,
              ),
            ),
          ],
        ),
      ),
      loading: () => const SizedBox(height: 100),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCountCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: card,
    );
  }

  Widget _buildReceivingsList(
    BuildContext context,
    WidgetRef ref,
    List<ReceivingEntity> receivings,
  ) {
    if (receivings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.cube_box, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Receiving Records',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start receiving stock to see records here',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return ListView.builder(
      itemCount: receivings.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        final receiving = receivings[index];
        return _buildReceivingItem(context, receiving, dateFormat);
      },
    );
  }

  Widget _buildReceivingItem(
    BuildContext context,
    ReceivingEntity receiving,
    DateFormat dateFormat,
  ) {
    final theme = Theme.of(context);
    final (bg, fg, icon) = _statusVisuals(receiving.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: fg),
        ),
        title: Text(
          receiving.referenceNumber,
          style: const TextStyle(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
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
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                receiving.status.displayName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(height: 2),
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

  (Color, Color, IconData) _statusVisuals(ReceivingStatus status) {
    switch (status) {
      case ReceivingStatus.completed:
        return (Colors.green[50]!, Colors.green[700]!,
            CupertinoIcons.checkmark_circle);
      case ReceivingStatus.draft:
        return (Colors.orange[50]!, Colors.orange[700]!,
            CupertinoIcons.square_pencil);
      case ReceivingStatus.cancelled:
        return (Colors.grey[200]!, Colors.grey[700]!, CupertinoIcons.xmark);
    }
  }

  Future<void> _startNewReceiving(BuildContext context, WidgetRef ref) async {
    await ref.read(currentReceivingProvider.notifier).initNewReceiving();

    if (context.mounted) {
      context.push(RoutePaths.bulkReceiving);
    }
  }
}
