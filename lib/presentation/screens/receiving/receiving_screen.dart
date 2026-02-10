import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';
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
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Receiving'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () {
              // Navigate to full history
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary cards
          _buildSummaryCards(ref),

          // Draft receivings
          _buildDraftSection(ref),

          // Recent receivings
          Expanded(
            child: receivingsAsync.when(
              data: (receivings) =>
                  _buildReceivingsList(context, ref, receivings),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startNewReceiving(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Receiving'),
      ),
    );
  }

  Widget _buildSummaryCards(WidgetRef ref) {
    final countsAsync = ref.watch(receivingCountsProvider);

    return countsAsync.when(
      data: (counts) => Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildCountCard(
                'Drafts',
                '${counts[ReceivingStatus.draft] ?? 0}',
                Icons.edit_note,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCountCard(
                'Completed',
                '${counts[ReceivingStatus.completed] ?? 0}',
                Icons.check_circle,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCountCard(
                'This Month',
                '${(counts[ReceivingStatus.completed] ?? 0) + (counts[ReceivingStatus.draft] ?? 0)}',
                Icons.calendar_today,
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
    Color color,
  ) {
    return Container(
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
  }

  Widget _buildDraftSection(WidgetRef ref) {
    final draftsAsync = ref.watch(draftReceivingsProvider);

    return draftsAsync.when(
      data: (drafts) {
        if (drafts.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_note, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Text(
                    '${drafts.length} Draft${drafts.length > 1 ? 's' : ''} Pending',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...drafts.take(3).map((draft) => _buildDraftItem(ref, draft)),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildDraftItem(WidgetRef ref, ReceivingEntity draft) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${draft.referenceNumber} - ${draft.uniqueProductCount} items',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () {
              // Resume draft
            },
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivingsList(
    BuildContext context,
    WidgetRef ref,
    List<ReceivingEntity> receivings,
  ) {
    final completedReceivings =
        receivings.where((r) => r.status == ReceivingStatus.completed).toList();

    if (completedReceivings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
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
      itemCount: completedReceivings.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        final receiving = completedReceivings[index];
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.inventory, color: Colors.green[700]),
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
        onTap: () {
          // Navigate to receiving detail
        },
      ),
    );
  }

  Future<void> _startNewReceiving(BuildContext context, WidgetRef ref) async {
    await ref.read(currentReceivingProvider.notifier).initNewReceiving();

    if (context.mounted) {
      context.push(RoutePaths.bulkReceiving);
    }
  }
}
