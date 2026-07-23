import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/utils/job_order_number.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/draft_dialogs.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/draft_list_tile.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/new_job_order_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Screen listing active Job Orders (open service tickets).
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
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: 'New Job Order',
            onPressed: () => _createJobOrder(context, ref),
          ),
        ],
      ),
      body: draftsAsync.when(
        data: (drafts) => _buildDraftsList(context, ref, drafts),
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorStateView(
          message: 'Failed to load job orders\n$error',
          onRetry: () => ref.invalidate(activeDraftsProvider),
        ),
      ),
    );
  }

  Future<void> _createJobOrder(BuildContext context, WidgetRef ref) async {
    // Sequential per-day number derived from today's existing job orders
    // (converted ones included so billed-out numbers are never reissued) —
    // mirrors pos_screen._showSaveDraftDialog.
    final now = DateTime.now();
    final String jobOrderNo;
    try {
      final todaysDrafts = await context.runWithWaiting(
        () => ref.read(draftRepositoryProvider).getDraftsByDateRange(
              startDate: now,
              endDate: now,
              includeConverted: true,
            ),
        message: 'Preparing…',
      );
      jobOrderNo =
          nextJobOrderNumber(now, todaysDrafts.map((d) => d.name));
    } catch (_) {
      if (context.mounted) {
        context.showErrorSnackBar('Could not prepare a job order number');
      }
      return;
    }
    if (!context.mounted) return;

    final input = await showNewJobOrderDialog(context, jobOrderNo: jobOrderNo);
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
        icon: LucideIcons.clipboardList,
        tiled: true,
        title: 'No job orders yet',
        subtitle:
            'Tap New Job Order to open a ticket for a bike being serviced.',
        action: FilledButton.icon(
          onPressed: () => _createJobOrder(context, ref),
          icon: const Icon(LucideIcons.plus),
          label: const Text('New Job Order'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(activeDraftsProvider);
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
            onTap: () => _openEditor(context, draft),
            onLoadTap: () => _openEditor(context, draft),
            onDeleteTap: canDelete
                ? () => _confirmDeleteDraft(context, ref, draft)
                : null,
          );
        },
      ),
    );
  }

  void _openEditor(BuildContext context, DraftEntity draft) {
    context.pushNamed(RouteNames.draftEdit, pathParameters: {'id': draft.id});
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
