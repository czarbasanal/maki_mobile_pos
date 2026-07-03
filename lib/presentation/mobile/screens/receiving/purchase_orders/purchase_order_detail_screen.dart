import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/core/utils/purchase_order_csv.dart';
import 'package:maki_mobile_pos/core/utils/report_export.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/purchase_orders/purchase_order_status_style.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/purchase_order_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_waiting_dialog.dart';

/// Purchase order detail: items (editable while draft) + lifecycle actions.
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

  @override
  Widget build(BuildContext context) {
    final poAsync = ref.watch(purchaseOrderProvider(widget.purchaseOrderId));
    final isAdmin =
        ref.watch(currentUserProvider).valueOrNull?.role == UserRole.admin;
    final dark = Theme.of(context).brightness == Brightness.dark;

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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (po) => po == null
            ? const Center(child: Text('Purchase order not found'))
            : _buildBody(po, dark),
      ),
    );
  }

  Widget _buildBody(PurchaseOrderEntity po, bool dark) {
    final style = PurchaseOrderStatusStyle.of(po.status, dark: dark);
    String date(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

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
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: style.tint,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(style.icon,
                                  size: 12, color: style.textColor),
                              const SizedBox(width: 4),
                              Text(style.label,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: style.textColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(po.supplierName ?? 'No supplier'),
                    Text('Created ${date(po.createdAt)} by ${po.createdByName}',
                        style: Theme.of(context).textTheme.bodySmall),
                    if (po.orderedAt != null)
                      Text('Ordered ${date(po.orderedAt!)}',
                          style: Theme.of(context).textTheme.bodySmall),
                    if (po.receivedAt != null)
                      Text('Received ${date(po.receivedAt!)}',
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
              Text('${po.items.length} items • ${po.totalQuantity} pcs',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final item in po.items) _itemRow(po, item),
            ],
          ),
        ),
        SafeArea(child: _actionBar(po)),
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
                : () =>
                    _updateItem(po, item.copyWith(quantity: item.quantity - 1)),
          ),
          Text('${item.quantity}'),
          IconButton(
            icon: const Icon(LucideIcons.plus, size: 16),
            onPressed: _busy
                ? null
                : () =>
                    _updateItem(po, item.copyWith(quantity: item.quantity + 1)),
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 16),
            onPressed: _busy ? null : () => _removeItem(po, item),
          ),
        ] else
          Text('${item.quantity} ${item.unit}'),
      ],
    );
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

  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() => _busy = true);
    try {
      await context.runWithWaiting(action, message: message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateItem(
      PurchaseOrderEntity po, PurchaseOrderItemEntity updated) {
    final items =
        po.items.map((i) => i.id == updated.id ? updated : i).toList();
    return _run(
      () async => ref
          .read(purchaseOrderRepositoryProvider)
          .updatePurchaseOrder(po.copyWith(items: items).recalculateTotals()),
      'Updating…',
    );
  }

  Future<void> _removeItem(
      PurchaseOrderEntity po, PurchaseOrderItemEntity item) {
    if (po.items.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Last item — delete the purchase order instead')));
      return Future.value();
    }
    final items = po.items.where((i) => i.id != item.id).toList();
    return _run(
      () async => ref
          .read(purchaseOrderRepositoryProvider)
          .updatePurchaseOrder(po.copyWith(items: items).recalculateTotals()),
      'Updating…',
    );
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareCsv(PurchaseOrderEntity po) => saveReportCsv(
      context, buildPurchaseOrderCsv(po), '${po.referenceNumber}.csv');

  Future<void> _onMenu(String value, PurchaseOrderEntity po) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(value == 'cancel'
            ? 'Cancel this purchase order?'
            : 'Delete this purchase order?'),
        content: Text(value == 'cancel'
            ? '${po.referenceNumber} will be marked cancelled.'
            : '${po.referenceNumber} will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(value == 'cancel' ? 'Cancel order' : 'Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (value == 'cancel') {
      await _run(
          () => ref
              .read(purchaseOrderRepositoryProvider)
              .cancelPurchaseOrder(po.id),
          'Cancelling…');
    } else {
      await _run(
          () => ref
              .read(purchaseOrderRepositoryProvider)
              .deletePurchaseOrder(po.id),
          'Deleting…');
      if (mounted) context.pop();
    }
  }
}
