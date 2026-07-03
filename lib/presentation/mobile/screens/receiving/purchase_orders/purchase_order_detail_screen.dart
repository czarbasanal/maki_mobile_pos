import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/core/extensions/datetime_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/utils/purchase_order_csv.dart';
import 'package:maki_mobile_pos/core/utils/report_export.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/purchase_orders/purchase_order_status_pill.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/purchase_order_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_waiting_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';

/// Purchase order detail: items (editable while draft, buffered locally and
/// flushed with one write) + lifecycle actions.
class PurchaseOrderDetailScreen extends ConsumerStatefulWidget {
  const PurchaseOrderDetailScreen({super.key, required this.purchaseOrderId});

  final String purchaseOrderId;

  @override
  ConsumerState<PurchaseOrderDetailScreen> createState() =>
      PurchaseOrderDetailScreenState();
}

class PurchaseOrderDetailScreenState
    extends ConsumerState<PurchaseOrderDetailScreen> {
  bool _busy = false;

  /// Unsaved draft item edits. Null = clean; non-null shows Save/Discard and
  /// gates lifecycle actions until flushed (one write) or dropped.
  List<PurchaseOrderItemEntity>? _pending;

  bool get _dirty => _pending != null;

  @override
  Widget build(BuildContext context) {
    final poAsync = ref.watch(purchaseOrderProvider(widget.purchaseOrderId));
    final isAdmin =
        ref.watch(currentUserProvider).valueOrNull?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('Purchase Order'),
        actions: [
          poAsync.maybeWhen(
            data: (po) {
              if (po == null || (!po.canCancel && !isAdmin)) {
                return const SizedBox.shrink();
              }
              return PopupMenuButton<String>(
                onSelected: (v) => _onMenu(v, po),
                itemBuilder: (_) => [
                  if (po.canCancel)
                    const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
                  if (isAdmin)
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: poAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorStateView(message: 'Failed to load: $e'),
        data: (po) => po == null
            ? const EmptyStateView(
                icon: LucideIcons.fileX,
                title: 'Purchase order not found',
              )
            : _buildBody(po),
      ),
    );
  }

  Widget _buildBody(PurchaseOrderEntity po) {
    final items = _pending ?? po.items;
    final totalQuantity =
        items.fold<int>(0, (sum, item) => sum + item.quantity);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(po.referenceNumber,
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        PurchaseOrderStatusPill(status: po.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(po.supplierName ?? 'No supplier'),
                    Text(
                        'Created ${po.createdAt.toIsoDate()} by ${po.createdByName}',
                        style: Theme.of(context).textTheme.bodySmall),
                    if (po.orderedAt != null)
                      Text('Ordered ${po.orderedAt!.toIsoDate()}',
                          style: Theme.of(context).textTheme.bodySmall),
                    if (po.receivedAt != null)
                      Text('Received ${po.receivedAt!.toIsoDate()}',
                          style: Theme.of(context).textTheme.bodySmall),
                    if (po.notes != null && po.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(po.notes!,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('${items.length} items • $totalQuantity pcs',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final item in items) _itemRow(po, item),
            ],
          ),
        ),
        SafeArea(child: _dirty ? _editBar(po) : _actionBar(po)),
      ],
    );
  }

  Widget _itemRow(PurchaseOrderEntity po, PurchaseOrderItemEntity item) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(item.sku, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (po.canEdit) ...[
          IconButton(
            icon: const Icon(LucideIcons.minus, size: 16),
            onPressed: _busy || item.quantity <= 1
                ? null
                : () => _stageQty(po, item, item.quantity - 1),
          ),
          Text('${item.quantity}'),
          IconButton(
            icon: const Icon(LucideIcons.plus, size: 16),
            onPressed:
                _busy ? null : () => _stageQty(po, item, item.quantity + 1),
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 16),
            onPressed: _busy ? null : () => _stageRemove(po, item),
          ),
        ] else
          Text('${item.quantity} ${item.unit}'),
      ],
    );
  }

  void _stageQty(PurchaseOrderEntity po, PurchaseOrderItemEntity item, int qty) {
    final items = List.of(_pending ?? po.items);
    final idx = items.indexWhere((i) => i.id == item.id);
    if (idx < 0) return;
    items[idx] = item.copyWith(quantity: qty);
    setState(() => _pending = items);
  }

  void _stageRemove(PurchaseOrderEntity po, PurchaseOrderItemEntity item) {
    final items = List.of(_pending ?? po.items);
    if (items.length == 1) {
      context.showSnackBar('Last item — delete the purchase order instead');
      return;
    }
    items.removeWhere((i) => i.id == item.id);
    setState(() => _pending = items);
  }

  Widget _editBar(PurchaseOrderEntity po) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: _busy ? null : () => _saveChanges(po),
              child: const Text('Save changes'),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _busy ? null : () => setState(() => _pending = null),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges(PurchaseOrderEntity po) async {
    final items = _pending;
    if (items == null) return;
    final ok = await _run(
      () async => ref.read(purchaseOrderRepositoryProvider).updatePurchaseOrder(
          po.copyWith(items: items).recalculateTotals()),
      'Saving…',
    );
    if (ok && mounted) setState(() => _pending = null);
  }

  Widget _actionBar(PurchaseOrderEntity po) {
    final buttons = <Widget>[];
    if (po.status == PurchaseOrderStatus.draft) {
      buttons.add(FilledButton(
        onPressed: _busy
            ? null
            : () => _run(
                () =>
                    ref.read(purchaseOrderRepositoryProvider).markOrdered(po.id),
                'Marking ordered…'),
        child: const Text('Mark ordered'),
      ));
    }
    if (po.status == PurchaseOrderStatus.ordered) {
      buttons.add(FilledButton(
        onPressed: _busy ? null : () => _receive(po),
        child: const Text('Receive'),
      ));
      buttons.add(OutlinedButton(
        onPressed: _busy
            ? null
            : () => _run(
                () => ref
                    .read(purchaseOrderRepositoryProvider)
                    .revertToDraft(po.id),
                'Reopening…'),
        child: const Text('Back to draft'),
      ));
    }
    if (po.status != PurchaseOrderStatus.cancelled) {
      buttons.add(OutlinedButton.icon(
        onPressed: _busy ? null : () => _shareCsv(po),
        icon: const Icon(LucideIcons.share2, size: 16),
        label: const Text('Share CSV'),
      ));
    }
    if (po.status == PurchaseOrderStatus.received && po.receivingId != null) {
      buttons.add(OutlinedButton(
        onPressed: () =>
            context.push('${RoutePaths.bulkReceiving}/${po.receivingId}'),
        child: const Text('View receiving'),
      ));
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(spacing: 8, runSpacing: 8, children: buttons),
    );
  }

  /// Runs [action] behind the waiting dialog; returns whether it succeeded so
  /// callers can gate follow-up navigation on the outcome.
  Future<bool> _run(Future<void> Function() action, String message) async {
    setState(() => _busy = true);
    try {
      await context.runWithWaiting(action, message: message);
      return true;
    } catch (e) {
      if (mounted) context.showErrorSnackBar('Failed: $e');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _receive(PurchaseOrderEntity po) async {
    setState(() => _busy = true);
    try {
      // .future rather than .valueOrNull — the provider may not have emitted
      // yet when nothing else in the tree watches it.
      final user = await ref.read(currentUserProvider.future);
      if (user == null || !mounted) return;
      final rid = await context.runWithWaiting(() async {
        final refNum = await ref
            .read(receivingRepositoryProvider)
            .generateReferenceNumber();
        return ref.read(purchaseOrderRepositoryProvider).startReceiving(
              purchaseOrderId: po.id,
              receivingReferenceNumber: refNum,
              createdBy: user.id,
              createdByName: user.displayName,
            );
      }, message: 'Preparing receiving…');
      if (!mounted) return;
      // Widget tests pump this screen without a GoRouter; the receiving draft
      // exists either way, so navigation is best-effort.
      GoRouter.maybeOf(context)?.push('${RoutePaths.bulkReceiving}/$rid');
    } catch (e) {
      if (mounted) context.showErrorSnackBar('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareCsv(PurchaseOrderEntity po) => saveReportCsv(
      context, buildPurchaseOrderCsv(po), '${po.referenceNumber}.csv');

  Future<void> _onMenu(String value, PurchaseOrderEntity po) async {
    final isDelete = value == 'delete';
    final confirmed = await showAppConfirmDialog(
      context,
      title: isDelete ? 'Delete this purchase order?' : 'Cancel this purchase order?',
      message: isDelete
          ? '${po.referenceNumber} will be permanently removed.'
          : '${po.referenceNumber} will be marked cancelled.',
      confirmLabel: isDelete ? 'Delete' : 'Cancel order',
      cancelLabel: 'Keep',
      icon: isDelete ? LucideIcons.trash2 : LucideIcons.ban,
      destructive: true,
      warningText: po.receivingId != null
          ? 'Its in-progress receiving draft will be cancelled too.'
          : null,
    );
    if (!confirmed || !mounted) return;
    if (isDelete) {
      final ok = await _run(
          () => ref
              .read(purchaseOrderRepositoryProvider)
              .deletePurchaseOrder(po.id),
          'Deleting…');
      if (ok && mounted) context.pop();
    } else {
      await _run(
          () => ref
              .read(purchaseOrderRepositoryProvider)
              .cancelPurchaseOrder(po.id),
          'Cancelling…');
    }
  }
}
