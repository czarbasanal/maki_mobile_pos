import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/core/extensions/datetime_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/purchase_orders/po_widgets.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/purchase_orders/purchase_order_status_pill.dart';
import 'package:maki_mobile_pos/presentation/providers/purchase_order_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';

/// Purchase orders list — status filter pills over streamed PO cards.
/// Redesign: design/design_handoff_purchase_orders (screen 1 + 2).
class PurchaseOrdersScreen extends ConsumerStatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  ConsumerState<PurchaseOrdersScreen> createState() =>
      _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends ConsumerState<PurchaseOrdersScreen> {
  PurchaseOrderStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(purchaseOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          // Top-level destination (dashboard Reorder pill uses `go`) — there
          // may be nothing to pop.
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Purchase Orders'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: 'New purchase order',
            onPressed: () => context.push(RoutePaths.purchaseOrderNew),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterPill(
                  key: const Key('po-filter-all'),
                  label: 'All',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final status in PurchaseOrderStatus.values) ...[
                  const SizedBox(width: 8),
                  _FilterPill(
                    key: Key('po-filter-${status.name}'),
                    label: status.displayName,
                    selected: _filter == status,
                    onTap: () => setState(() => _filter = status),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorStateView(
                message: 'Failed to load: $e',
                onRetry: () => ref.invalidate(purchaseOrdersProvider),
              ),
              data: (orders) {
                final visible = _filter == null
                    ? orders
                    : orders.where((o) => o.status == _filter).toList();
                if (visible.isEmpty) {
                  return EmptyStateView(
                    tiled: true,
                    icon: LucideIcons.clipboardList,
                    title: 'No purchase orders yet',
                    subtitle: 'Suggestions come from your stock movement. '
                        'Start one to draft what to buy.',
                    action: FilledButton.icon(
                      onPressed: () =>
                          context.push(RoutePaths.purchaseOrderNew),
                      icon: const Icon(LucideIcons.plus, size: 18),
                      label: const Text('New purchase order'),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _OrderCard(order: visible[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 34px status filter pill — selected = solid primary fill (slate/gold),
/// unselected = card surface + hairline border.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : (dark ? AppColors.darkCard : AppColors.lightCard),
          border:
              selected ? null : Border.all(color: AppColors.hairline(dark)),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final PurchaseOrderEntity order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final items = order.uniqueProductCount;
    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(13),
      onTap: () => context.push('${RoutePaths.purchaseOrders}/${order.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PoGlyphTile(icon: LucideIcons.clipboardList),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.supplierName ?? 'No supplier',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      order.referenceNumber,
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
              PurchaseOrderStatusPill(status: order.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '$items ${items == 1 ? 'item' : 'items'} · '
                  '${order.totalQuantity} pcs · by ${order.createdByName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: secondary),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Totals addition (user-approved; not in the mock): PO grand
                  // total in the Job Orders money language.
                  Text(
                    order.totalCost.toCurrency(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.createdAt.toFriendlyDateTime(),
                    style: TextStyle(fontSize: 12, color: secondary),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
