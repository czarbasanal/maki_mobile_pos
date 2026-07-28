import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/utils/job_order_number.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/job_orders/job_order_dialogs.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/job_orders/job_order_list_tile.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/job_orders/new_job_order_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Screen listing active Job Orders (open service tickets).
class JobOrdersListScreen extends ConsumerWidget {
  const JobOrdersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobOrdersAsync = ref.watch(activeJobOrdersProvider);

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
      body: jobOrdersAsync.when(
        data: (jobOrders) => _buildJobOrdersList(context, ref, jobOrders),
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorStateView(
          message: 'Failed to load job orders\n$error',
          onRetry: () => ref.invalidate(activeJobOrdersProvider),
        ),
      ),
    );
  }

  Future<void> _createJobOrder(BuildContext context, WidgetRef ref) async {
    // Sequential per-day number derived from today's existing job orders
    // (converted ones included so billed-out numbers are never reissued) —
    // mirrors pos_screen._showSaveJobOrderDialog.
    final now = DateTime.now();
    final String jobOrderNo;
    try {
      final todaysJobOrders = await context.runWithWaiting(
        () => ref.read(jobOrderRepositoryProvider).getJobOrdersByDateRange(
              startDate: now,
              endDate: now,
              includeConverted: true,
            ),
        message: 'Preparing…',
      );
      jobOrderNo = nextJobOrderNumber(now, todaysJobOrders.map((d) => d.name));
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
    final jobOrder = JobOrderEntity(
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
          .read(jobOrderOperationsProvider.notifier)
          .createJobOrder(actor: user, jobOrder: jobOrder),
      message: 'Creating…',
    );
    if (created != null && context.mounted) {
      context.pushNamed(RouteNames.jobOrderEdit,
          pathParameters: {'id': created.id});
    }
  }

  Widget _buildJobOrdersList(
    BuildContext context,
    WidgetRef ref,
    List<JobOrderEntity> jobOrders,
  ) {
    if (jobOrders.isEmpty) {
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
        ref.invalidate(activeJobOrdersProvider);
        await ref.read(activeJobOrdersProvider.future);
      },
      child: ListView.builder(
        itemCount: jobOrders.length,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (context, index) {
          final jobOrder = jobOrders[index];
          // Mirrors firestore.rules: creator or admin can delete.
          final user = ref.read(currentUserProvider).valueOrNull;
          final canDelete =
              user != null && (user.isAdmin || jobOrder.createdBy == user.id);
          return JobOrderListTile(
            jobOrder: jobOrder,
            onTap: () => _openEditor(context, jobOrder),
            onLoadTap: () => _openEditor(context, jobOrder),
            onDeleteTap: canDelete
                ? () => _confirmDeleteJobOrder(context, ref, jobOrder)
                : null,
          );
        },
      ),
    );
  }

  void _openEditor(BuildContext context, JobOrderEntity jobOrder) {
    context.pushNamed(RouteNames.jobOrderEdit,
        pathParameters: {'id': jobOrder.id});
  }

  void _confirmDeleteJobOrder(
    BuildContext context,
    WidgetRef ref,
    JobOrderEntity jobOrder,
  ) {
    showDeleteJobOrderDialog(context, jobOrder, () {
      _performDeleteJobOrder(context, ref, jobOrder);
    });
  }

  Future<void> _performDeleteJobOrder(
    BuildContext context,
    WidgetRef ref,
    JobOrderEntity jobOrder,
  ) async {
    final actor = ref.read(currentUserProvider).value;
    if (actor == null) return;
    final jobOrderOps = ref.read(jobOrderOperationsProvider.notifier);
    final success =
        await jobOrderOps.deleteJobOrder(actor: actor, jobOrderId: jobOrder.id);

    if (context.mounted) {
      if (success) {
        context.showSuccessSnackBar('Job order deleted');
      } else {
        context.showErrorSnackBar('Failed to delete job order');
      }
    }
  }
}
