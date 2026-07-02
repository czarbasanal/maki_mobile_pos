import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/draft_detail_sheet.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/draft_dialogs.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/draft_list_tile.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/new_job_order_dialog.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/settings/settings_crud_row.dart';
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
        title: const Text('Job Orders'),
      ),
      body: draftsAsync.when(
        data: (drafts) => _buildDraftsList(context, ref, drafts),
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorStateView(
          message: 'Failed to load job orders\n$error',
          onRetry: () => ref.invalidate(activeDraftsProvider),
        ),
      ),
      floatingActionButton: SettingsAddFab(
        label: 'New Job Order',
        onPressed: () => _createJobOrder(context, ref),
      ),
    );
  }

  Future<void> _createJobOrder(BuildContext context, WidgetRef ref) async {
    final input = await showNewJobOrderDialog(context);
    if (input == null) return;
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    final draft = DraftEntity(
      id: '',
      name: input.label,
      items: const [],
      motorcycleModel: input.model,
      mechanicId: input.mechanicId,
      mechanicName: input.mechanicName,
      createdBy: user.id,
      createdByName: user.displayName,
      createdAt: DateTime.now(),
    );
    if (!context.mounted) return;
    final created = await context.runWithWaiting(
      () => ref
          .read(draftOperationsProvider.notifier)
          .createDraft(actor: user, draft: draft),
      message: 'Creating…',
    );
    if (created != null && context.mounted) {
      context.pushNamed(RouteNames.draftEdit,
          pathParameters: {'id': created.id});
    }
  }

  Widget _buildDraftsList(
    BuildContext context,
    WidgetRef ref,
    List<DraftEntity> drafts,
  ) {
    if (drafts.isEmpty) {
      return EmptyStateView(
        icon: LucideIcons.shoppingCart,
        title: 'No job orders yet',
        subtitle: "Open a job order for a bike being serviced and it'll appear here.",
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
      backgroundColor: Colors.transparent,
      barrierColor: AppDialog.scrimColor(
          Theme.of(context).brightness == Brightness.dark),
      // Use `sheetContext` only to pop the sheet; hand the stable *screen*
      // `context` to the async handlers. The sheet's context unmounts once it
      // pops, which (now that the handlers await) would drop the post-await
      // navigation / error snackbar.
      // Use `sheetContext` only to pop the sheet; hand the stable *screen*
      // `context` to the async handlers. The sheet's context unmounts once it
      // pops, which (now that the handlers await) would drop the post-await
      // navigation / error snackbar.
      builder: (sheetContext) => DraftDetailSheet(
        draft: draft,
        onLoad: () {
          Navigator.pop(sheetContext);
          _loadDraftIntoCart(context, ref, draft);
        },
        onDelete: canDelete
            ? () {
                Navigator.pop(sheetContext);
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

  Future<void> _performLoadDraft(
    BuildContext context,
    WidgetRef ref,
    DraftEntity draft,
  ) async {
    // Load draft into cart and drop it from the saved-drafts collection.
    // Loading consumes the draft — if the user cancels and saves again, a
    // new entry is created.
    ref.read(cartProvider.notifier).loadFromDraft(draft);
    ref.read(selectedDraftProvider.notifier).state = null;

    final actor = ref.read(currentUserProvider).valueOrNull;
    if (actor != null) {
      // Await the delete so a failure is observed rather than silently
      // dropped (which would leave the consumed draft lingering in the list).
      final deleted = await ref
          .read(draftOperationsProvider.notifier)
          .deleteDraft(actor: actor, draftId: draft.id);
      if (!deleted) {
        // Stay on the drafts screen so the snackbar survives — navigating to
        // POS first would tear it down (the reason the old success toast was
        // dropped). The draft is still listed, so the user can retry.
        if (context.mounted) {
          context.showErrorSnackBar(
            "Couldn't remove the job order. Please try again.",
          );
        }
        return;
      }
    }

    // Navigate back to POS — visual feedback (cart populated + draft gone
    // from the list) is sufficient.
    if (context.mounted) context.go(RoutePaths.pos);
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
        context.showSuccessSnackBar('Job order deleted');
      } else {
        context.showErrorSnackBar('Failed to delete job order');
      }
    }
  }
}
