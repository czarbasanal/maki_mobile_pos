import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/draft_detail_sheet.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/draft_dialogs.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/draft_list_tile.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Screen displaying all active drafts.
class DraftsListScreen extends ConsumerWidget {
  const DraftsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(activeDraftsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.pos),
        ),
        title: const Text('Saved Drafts'),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(activeDraftsProvider),
          ),
        ],
      ),
      body: draftsAsync.when(
        data: (drafts) => _buildDraftsList(context, ref, drafts),
        loading: () => const LoadingView(),
        error: (error, _) => ErrorStateView(
          message: 'Failed to load drafts\n$error',
          onRetry: () => ref.invalidate(activeDraftsProvider),
        ),
      ),
    );
  }

  Widget _buildDraftsList(
    BuildContext context,
    WidgetRef ref,
    List<DraftEntity> drafts,
  ) {
    if (drafts.isEmpty) {
      return EmptyStateView(
        icon: LucideIcons.mail,
        title: 'No Saved Drafts',
        subtitle: 'Drafts you save from the POS screen will appear here.',
        action: FilledButton.icon(
          onPressed: () => context.go(RoutePaths.pos),
          icon: const Icon(LucideIcons.shoppingCart),
          label: const Text('Go to POS'),
        ),
      );
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
          // Mirrors firestore.rules: creator or admin can delete.
          final user = ref.read(currentUserProvider).valueOrNull;
          final canDelete =
              user != null && (user.isAdmin || draft.createdBy == user.id);
          return DraftListTile(
            draft: draft,
            onTap: () => _showDraftDetails(context, ref, draft),
            onLoadTap: () => _loadDraftIntoCart(context, ref, draft),
            onDeleteTap:
                canDelete ? () => _confirmDeleteDraft(context, ref, draft) : null,
          );
        },
      ),
    );
  }

  void _showDraftDetails(
    BuildContext context,
    WidgetRef ref,
    DraftEntity draft,
  ) {
    final user = ref.read(currentUserProvider).valueOrNull;
    final canDelete =
        user != null && (user.isAdmin || draft.createdBy == user.id);
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
        onDelete: canDelete
            ? () {
                Navigator.pop(context);
                _confirmDeleteDraft(context, ref, draft);
              }
            : null,
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
      _confirmReplaceCart(context, ref, draft, cart.totalItemCount);
    } else {
      _performLoadDraft(context, ref, draft);
    }
  }

  Future<void> _confirmReplaceCart(
    BuildContext context,
    WidgetRef ref,
    DraftEntity draft,
    int cartCount,
  ) async {
    // Non-destructive primary action: slate/gold filled, never red.
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Replace cart?',
      message:
          'Your current cart has $cartCount item${cartCount == 1 ? '' : 's'}. '
          'Loading this draft will replace them.',
      confirmLabel: 'Replace',
      icon: LucideIcons.refreshCw,
    );
    if (confirmed && context.mounted) {
      _performLoadDraft(context, ref, draft);
    }
  }

  void _performLoadDraft(
    BuildContext context,
    WidgetRef ref,
    DraftEntity draft,
  ) {
    // Load draft into cart and immediately drop it from the saved-drafts
    // collection. Loading consumes the draft — if the user cancels and
    // saves again, a new entry is created. The activeDraftCountProvider
    // stream picks up the deletion and decrements the badge.
    ref.read(cartProvider.notifier).loadFromDraft(draft);
    ref.read(selectedDraftProvider.notifier).state = null;

    final actor = ref.read(currentUserProvider).valueOrNull;
    if (actor != null) {
      // Fire-and-forget; UI already moved on. Errors surface via the
      // operations notifier's AsyncValue.error if we ever wire them up.
      ref
          .read(draftOperationsProvider.notifier)
          .deleteDraft(actor: actor, draftId: draft.id);
    }

    // Navigate back to POS — visual feedback (cart populated + draft gone
    // from the list) is sufficient; previous toast didn't reliably dismiss
    // through the route transition.
    context.go(RoutePaths.pos);
  }

  void _confirmDeleteDraft(
    BuildContext context,
    WidgetRef ref,
    DraftEntity draft,
  ) {
    showDeleteDraftDialog(context, draft, () {
      _performDeleteDraft(context, ref, draft);
    });
  }

  Future<void> _performDeleteDraft(
    BuildContext context,
    WidgetRef ref,
    DraftEntity draft,
  ) async {
    final actor = ref.read(currentUserProvider).value;
    if (actor == null) return;
    final draftOps = ref.read(draftOperationsProvider.notifier);
    final success =
        await draftOps.deleteDraft(actor: actor, draftId: draft.id);

    if (context.mounted) {
      if (success) {
        context.showSuccessSnackBar('Draft deleted');
      } else {
        context.showErrorSnackBar('Failed to delete draft');
      }
    }
  }
}
