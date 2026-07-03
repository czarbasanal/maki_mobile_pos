import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/core/extensions/datetime_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/purchase_order_csv.dart';
import 'package:maki_mobile_pos/core/utils/report_export.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/purchase_orders/po_widgets.dart';
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
        title: Text(
          poAsync.valueOrNull?.referenceNumber ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppTextStyles.monoFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          poAsync.maybeWhen(
            data: (po) {
              if (po == null || (!po.canCancel && !isAdmin)) {
                return const SizedBox.shrink();
              }
              return PopupMenuButton<String>(
                icon: const Icon(LucideIcons.ellipsisVertical, size: 20),
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
    final totalCost =
        items.fold<double>(0, (sum, item) => sum + item.totalCost);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            children: [
              _headerCard(po),
              PoSectionHeader(
                icon: LucideIcons.package,
                label: 'Items',
                trailing: '${items.length} '
                    '${items.length == 1 ? 'item' : 'items'} · '
                    '$totalQuantity pcs',
              ),
              for (final item in items) _itemRow(po, item),
            ],
          ),
        ),
        _footer(po, items, totalQuantity, totalCost),
      ],
    );
  }

  Widget _headerCard(PurchaseOrderEntity po) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = theme.colorScheme.onSurfaceVariant;
    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PoGlyphTile(icon: LucideIcons.truck),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      po.supplierName ?? 'No supplier',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      po.referenceNumber,
                      style: TextStyle(
                        fontFamily: AppTextStyles.monoFontFamily,
                        fontSize: 11,
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PurchaseOrderStatusPill(status: po.status),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.only(top: 11),
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.hairline(dark))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metaLine(LucideIcons.clock,
                    'Created ${po.createdAt.toFriendlyDateTime()} · by ${po.createdByName}'),
                if (po.orderedAt != null) ...[
                  const SizedBox(height: 4),
                  _metaLine(LucideIcons.send,
                      'Ordered ${po.orderedAt!.toFriendlyDateTime()}'),
                ],
                if (po.receivedAt != null) ...[
                  const SizedBox(height: 4),
                  _metaLine(LucideIcons.packageCheck,
                      'Received ${po.receivedAt!.toFriendlyDateTime()}'),
                ],
                if (po.notes != null && po.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(po.notes!,
                      style: TextStyle(fontSize: 12.5, color: secondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaLine(IconData icon, String text) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 14, color: secondary),
        const SizedBox(width: 8),
        Expanded(
          child:
              Text(text, style: TextStyle(fontSize: 12.5, color: secondary)),
        ),
      ],
    );
  }

  Widget _itemRow(PurchaseOrderEntity po, PurchaseOrderItemEntity item) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        radius: AppRadius.field,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            PoQtyBadge(quantity: item.quantity, locked: !po.canEdit),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'SKU: ${item.sku}',
                    style: TextStyle(
                      fontFamily: AppTextStyles.monoFontFamily,
                      fontSize: 11,
                      color: secondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Subtotal line (user-approved totals addition).
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.unitCost.toCurrency()} each',
                          style: TextStyle(fontSize: 12, color: secondary),
                        ),
                      ),
                      Text(
                        item.totalCost.toCurrency(),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (po.canEdit)
              Row(
                children: [
                  PoStepperButton(
                    icon: LucideIcons.minus,
                    onTap: _busy || item.quantity <= 1
                        ? null
                        : () => _stageQty(po, item, item.quantity - 1),
                  ),
                  const SizedBox(width: 4),
                  PoStepperButton(
                    icon: LucideIcons.plus,
                    onTap: _busy
                        ? null
                        : () => _stageQty(po, item, item.quantity + 1),
                  ),
                  const SizedBox(width: 4),
                  PoStepperButton(
                    icon: LucideIcons.x,
                    onTap: _busy ? null : () => _stageRemove(po, item),
                  ),
                ],
              )
            else
              Text(
                '${item.quantity} ${item.unit}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: secondary,
                ),
              ),
          ],
        ),
      ),
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

  /// Pinned footer: grand-total row (always, every status — totals addition)
  /// over the per-status actions. Staged edits swap the actions to
  /// Save changes / Discard in the same slot.
  Widget _footer(PurchaseOrderEntity po, List<PurchaseOrderItemEntity> items,
      int totalQuantity, double totalCost) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final actions = _dirty ? _editActions(po) : _statusActions(po);

    return Container(
      decoration: poFooterDecoration(dark),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text.rich(
                  TextSpan(
                    text: 'Total ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    children: [
                      TextSpan(
                        text: '(${items.length} '
                            '${items.length == 1 ? 'item' : 'items'} · '
                            '$totalQuantity pcs)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  totalCost.toCurrency(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            if (actions != null) ...[
              const SizedBox(height: 12),
              actions,
            ],
          ],
        ),
      ),
    );
  }

  Widget _editActions(PurchaseOrderEntity po) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: _busy ? null : () => _saveChanges(po),
            child: const Text('Save changes'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: _busy ? null : () => setState(() => _pending = null),
            child: const Text('Discard'),
          ),
        ),
      ],
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

  Widget? _statusActions(PurchaseOrderEntity po) {
    switch (po.status) {
      case PurchaseOrderStatus.draft:
        return Row(
          children: [
            Expanded(
              flex: 5,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _shareCsv(po),
                icon: const Icon(LucideIcons.share2, size: 17),
                label: const Text('Share CSV'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => ref
                            .read(purchaseOrderRepositoryProvider)
                            .markOrdered(po.id),
                        'Marking ordered…'),
                icon: const Icon(LucideIcons.send, size: 17),
                label: const Text('Mark ordered'),
              ),
            ),
          ],
        );
      case PurchaseOrderStatus.ordered:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => ref
                                .read(purchaseOrderRepositoryProvider)
                                .revertToDraft(po.id),
                            'Reopening…'),
                    icon: const Icon(LucideIcons.undo2, size: 17),
                    label: const Text('Back to draft'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _shareCsv(po),
                    icon: const Icon(LucideIcons.share2, size: 17),
                    label: const Text('Share CSV'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _receive(po),
                icon: const Icon(LucideIcons.packageCheck, size: 18),
                label: const Text('Receive delivery'),
              ),
            ),
          ],
        );
      case PurchaseOrderStatus.received:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _shareCsv(po),
                icon: const Icon(LucideIcons.share2, size: 17),
                label: const Text('Share CSV'),
              ),
            ),
            if (po.receivingId != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context
                      .push('${RoutePaths.bulkReceiving}/${po.receivingId}'),
                  child: const Text('View receiving'),
                ),
              ),
            ],
          ],
        );
      case PurchaseOrderStatus.cancelled:
        // Actions collapse; the grand-total row above still renders.
        return null;
    }
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
