import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/widgets/drafts/draft_detail_sheet.dart';
import 'package:maki_mobile_pos/presentation/widgets/drafts/draft_list_tile.dart';

/// Screen displaying all active drafts.
class DraftsListScreen extends ConsumerWidget {
  const DraftsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(activeDraftsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Drafts'),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(activeDraftsProvider),
          ),
        ],
      ),
      body: draftsAsync.when(
        data: (drafts) => _buildDraftsList(context, ref, drafts),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(context, ref, error),
      ),
    );
  }

  Widget _buildDraftsList(
    BuildContext context,
    WidgetRef ref,
    List<DraftEntity> drafts,
  ) {
    if (drafts.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(activeDraftsProvider);
        // Wait for the provider to refresh
        await ref.read(activeDraftsProvider.future);
      },
      child: ListView.builder(
        itemCount: drafts.length,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (context, index) {
          final draft = drafts[index];
          return DraftListTile(
            draft: draft,
            onTap: () => _showDraftDetails(context, ref, draft),
            onLoadTap: () => _loadDraftIntoCart(context, ref, draft),
            onDeleteTap: () => _confirmDeleteDraft(context, ref, draft),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.drafts_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No Saved Drafts',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Drafts you save from the POS screen will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.point_of_sale),
              label: const Text('Go to POS'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load drafts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.invalidate(activeDraftsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDraftDetails(
    BuildContext context,
    WidgetRef ref,
    DraftEntity draft,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraftDetailSheet(
        draft: draft,
        onLoad: () {
          Navigator.pop(context);
          _loadDraftIntoCart(context, ref, draft);
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDeleteDraft(context, ref, draft);
        },
      ),
    );
  }

  void _loadDraftIntoCart(
    BuildContext context,
    WidgetRef ref,
    DraftEntity draft,
  ) {
    final cart = ref.read(cartProvider);

    // Check if cart has items
    if (cart.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace Cart?'),
          content: Text(
            'Your current cart has ${cart.totalItemCount} item(s). '
            'Loading this draft will replace them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _performLoadDraft(context, ref, draft);
              },
              child: const Text('Replace'),
            ),
          ],
        ),
      );
    } else {
      _performLoadDraft(context, ref, draft);
    }
  }

  void _performLoadDraft(
    BuildContext context,
    WidgetRef ref,
    DraftEntity draft,
  ) {
    // Load draft into cart
    ref.read(cartProvider.notifier).loadFromDraft(draft);

    // Store selected draft for reference
    ref.read(selectedDraftProvider.notifier).state = draft;

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded draft: ${draft.name}'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Go to POS',
          textColor: Colors.white,
          onPressed: () {
            // Navigate to POS
            Navigator.pop(context);
          },
        ),
      ),
    );

    // Navigate back to POS
    Navigator.pop(context);
  }

  void _confirmDeleteDraft(
    BuildContext context,
    WidgetRef ref,
    DraftEntity draft,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Draft?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${draft.name}"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${draft.totalItemCount} item(s)',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Total: ${AppConstants.currencySymbol}${draft.grandTotal.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _performDeleteDraft(context, ref, draft);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteDraft(
    BuildContext context,
    WidgetRef ref,
    DraftEntity draft,
  ) async {
    final draftOps = ref.read(draftOperationsProvider.notifier);
    final success = await draftOps.deleteDraft(draft.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Draft deleted' : 'Failed to delete draft',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
