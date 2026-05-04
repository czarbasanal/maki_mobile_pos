import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart'
    show PriceHistoryEntry;
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/inventory_widgets.dart';
import 'package:intl/intl.dart';

/// Screen displaying detailed product information.
class ProductDetailScreen extends ConsumerWidget {
  final String productId;

  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productStreamProvider(productId));
    final inventoryState = ref.watch(inventoryStateProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    final isAdmin = currentUser?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.inventory),
        ),
        title: const Text('Product Details'),
        actions: [
          if (isAdmin)
            CostDisplayToggle(
              showCost: inventoryState.showCost,
              onToggle: (show) {
                ref
                    .read(inventoryStateProvider.notifier)
                    .toggleCostVisibility(show);
              },
            ),
          PopupMenuButton<String>(
            onSelected: (action) => _handleAction(context, ref, action),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(CupertinoIcons.pencil),
                  title: Text('Edit Product'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (isAdmin)
                const PopupMenuItem(
                  value: 'deactivate',
                  child: ListTile(
                    leading: Icon(
                      CupertinoIcons.archivebox,
                      color: AppColors.warningDark,
                    ),
                    title: Text('Deactivate'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ],
      ),
      body: productAsync.when(
        data: (product) {
          if (product == null) {
            return const Center(child: Text('Product not found'));
          }
          return _buildProductDetails(context, ref, product, inventoryState);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      bottomNavigationBar: productAsync.valueOrNull != null
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      _showStockAdjustment(context, productAsync.value!),
                  icon: const Icon(CupertinoIcons.pencil),
                  label: const Text('Adjust Stock'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildProductDetails(
    BuildContext context,
    WidgetRef ref,
    ProductEntity product,
    InventoryState inventoryState,
  ) {
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(context, product),
          const SizedBox(height: AppSpacing.md),
          _buildStockCard(context, product),
          const SizedBox(height: AppSpacing.md),
          _buildPricingCard(context, product, inventoryState.showCost),
          if (inventoryState.showCost) ...[
            const SizedBox(height: AppSpacing.md),
            _PriceHistoryCard(productId: product.id),
          ],
          const SizedBox(height: AppSpacing.md),
          _buildDetailsCard(context, product, dateFormat),
          if (product.supplierName != null) ...[
            const SizedBox(height: AppSpacing.md),
            _buildSupplierCard(context, product),
          ],
          if (product.notes != null && product.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _buildNotesCard(context, product),
          ],
          const SizedBox(height: AppSpacing.xxl + 32), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, ProductEntity product) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final mutedFill =
        isDark ? AppColors.darkSurfaceMuted : AppColors.lightSurfaceMuted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg - 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Outlined product glyph (no tinted background box)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(color: hairline),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    CupertinoIcons.cube_box,
                    size: 36,
                    color: muted,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: mutedFill,
                          border: Border.all(color: hairline),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          product.sku,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: muted,
                          ),
                        ),
                      ),
                      if (product.category != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Chip(
                          label: Text(product.category!),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (product.barcode != null && product.barcode!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(CupertinoIcons.qrcode, size: 18, color: muted),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Barcode: ${product.barcode}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStockCard(BuildContext context, ProductEntity product) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;

    final (statusColor, statusText, statusIcon) = _stockStatus(product);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg - 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              icon: CupertinoIcons.cube_box,
              title: 'Stock Information',
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _buildStockMetric(
                    context,
                    'Current Stock',
                    '${product.quantity}',
                    product.unit,
                    statusColor,
                  ),
                ),
                Container(width: 1, height: 60, color: hairline),
                Expanded(
                  child: _buildStockMetric(
                    context,
                    'Reorder Level',
                    '${product.reorderLevel}',
                    product.unit,
                    muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm + 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: statusColor),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockMetric(
    BuildContext context,
    String label,
    String value,
    String unit,
    Color color,
  ) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(
          unit,
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }

  Widget _buildPricingCard(
    BuildContext context,
    ProductEntity product,
    bool showCost,
  ) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg - 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              icon: AppIcons.peso,
              title: 'Pricing',
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _buildPriceColumn(
                    context,
                    'Selling Price',
                    '${AppConstants.currencySymbol}${product.price.toStringAsFixed(2)}',
                    theme.colorScheme.primary,
                  ),
                ),
                if (showCost) ...[
                  Container(width: 1, height: 60, color: hairline),
                  Expanded(
                    child: _buildPriceColumn(
                      context,
                      'Cost',
                      '${AppConstants.currencySymbol}${product.cost.toStringAsFixed(2)}',
                      theme.colorScheme.onSurface,
                    ),
                  ),
                  Container(width: 1, height: 60, color: hairline),
                  Expanded(
                    child: _buildPriceColumn(
                      context,
                      'Profit',
                      '${AppConstants.currencySymbol}${product.profit.toStringAsFixed(2)}',
                      AppColors.successDark,
                      subtitle: '${product.profitMargin.toStringAsFixed(1)}%',
                    ),
                  ),
                ] else ...[
                  Container(width: 1, height: 60, color: hairline),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Cost Code',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: muted),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm + 4,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.warning),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.lock,
                                size: 16,
                                color: AppColors.warningDark,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                product.costCode,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warningDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (showCost) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm + 4),
                decoration: BoxDecoration(
                  border: Border.all(color: hairline),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Inventory Value (at cost)',
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                    Text(
                      '${AppConstants.currencySymbol}${product.inventoryValueAtCost.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPriceColumn(
    BuildContext context,
    String label,
    String value,
    Color color, {
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
      ],
    );
  }

  Widget _buildDetailsCard(
    BuildContext context,
    ProductEntity product,
    DateFormat dateFormat,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg - 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              icon: CupertinoIcons.info_circle,
              title: 'Details',
            ),
            const SizedBox(height: AppSpacing.md),
            _buildDetailRow(context, 'Unit', product.unit),
            _buildDetailRow(
              context,
              'Status',
              product.isActive ? 'Active' : 'Inactive',
            ),
            _buildDetailRow(
              context,
              'Created',
              dateFormat.format(product.createdAt),
            ),
            if (product.updatedAt != null)
              _buildDetailRow(
                context,
                'Last Updated',
                dateFormat.format(product.updatedAt!),
              ),
            if (product.isVariation)
              _buildDetailRow(context, 'Base SKU', product.baseSku ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierCard(BuildContext context, ProductEntity product) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg - 4),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.briefcase,
              color: muted,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supplier',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  Text(
                    product.supplierName!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, color: muted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(BuildContext context, ProductEntity product) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg - 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              icon: CupertinoIcons.doc_text,
              title: 'Notes',
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            Text(product.notes!, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  void _showStockAdjustment(BuildContext context, ProductEntity product) {
    StockAdjustmentDialog.show(
      context: context,
      product: product,
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'edit':
        context.showSnackBar('Edit product coming soon');
        break;
      case 'deactivate':
        _confirmDeactivate(context, ref);
        break;
    }
  }

  void _confirmDeactivate(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Product?'),
        content: const Text(
          'This product will be hidden from POS and inventory lists. '
          'You can reactivate it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final currentUser = ref.read(currentUserProvider).value;
              if (currentUser != null) {
                await ref
                    .read(productOperationsProvider.notifier)
                    .deactivateProduct(
                      actor: currentUser,
                      productId: productId,
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                  context.showWarningSnackBar('Product deactivated');
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warningDark,
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

/// Status -> (color, label, icon) for a product's stock state.
(Color, String, IconData) _stockStatus(ProductEntity product) {
  if (product.isOutOfStock) {
    return (
      AppColors.error,
      'Out of Stock',
      CupertinoIcons.exclamationmark_circle,
    );
  }
  if (product.isLowStock) {
    return (
      AppColors.warning,
      'Low Stock',
      CupertinoIcons.exclamationmark_triangle,
    );
  }
  return (
    AppColors.success,
    'In Stock',
    CupertinoIcons.checkmark_circle,
  );
}

/// Price history card — shows every recorded change to selling price or cost
/// for this product, newest first. Reuses [priceHistoryProvider] which reads
/// the `products/{id}/price_history` subcollection. Gated on the cost toggle
/// upstream (admin-only).
class _PriceHistoryCard extends ConsumerWidget {
  const _PriceHistoryCard({required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(priceHistoryProvider(productId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg - 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              icon: CupertinoIcons.clock,
              title: 'Price History',
            ),
            const SizedBox(height: AppSpacing.md),
            historyAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return _buildEmptyState(context);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < entries.length; i++)
                      _PriceHistoryRow(
                        entry: entries[i],
                        // entries are newest-first; the "previous" entry for
                        // diffing is the next one in the list (older).
                        previous:
                            i + 1 < entries.length ? entries[i + 1] : null,
                        isFirst: i == 0,
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  'Could not load price history',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        'No price changes yet.',
        style: theme.textTheme.bodyMedium?.copyWith(color: muted),
      ),
    );
  }
}

class _PriceHistoryRow extends ConsumerWidget {
  const _PriceHistoryRow({
    required this.entry,
    required this.previous,
    required this.isFirst,
  });

  final PriceHistoryEntry entry;
  final PriceHistoryEntry? previous;
  final bool isFirst;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    final priceDelta = previous == null ? 0.0 : entry.price - previous!.price;
    final costDelta = previous == null ? 0.0 : entry.cost - previous!.cost;

    final userAsync = ref.watch(userByIdProvider(entry.changedBy));
    final who = userAsync.whenOrNull(
          data: (u) => u?.displayName,
        ) ??
        '—';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      decoration: isFirst
          ? null
          : BoxDecoration(
              border: Border(top: BorderSide(color: hairline)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _PriceLine(
                  label: 'Price',
                  value: entry.price,
                  delta: priceDelta,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _PriceLine(
                  label: 'Cost',
                  value: entry.cost,
                  delta: costDelta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                dateFormat.format(entry.changedAt),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              Text('•',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              Text(
                who,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (entry.reason != null && entry.reason!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: hairline),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    entry.reason!,
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ),
            ],
          ),
          if (entry.note != null && entry.note!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              entry.note!,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// One labelled value with an old→new directional arrow when it changed.
class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.label,
    required this.value,
    required this.delta,
  });

  final String label;
  final double value;
  final double delta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final changed = delta.abs() > 0.01;
    final up = delta > 0;
    final arrowColor =
        !changed ? muted : (up ? AppColors.successDark : AppColors.errorDark);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        Text(
          '${AppConstants.currencySymbol}${value.toStringAsFixed(2)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (changed) ...[
          const SizedBox(width: 4),
          Icon(
            up ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
            size: 12,
            color: arrowColor,
          ),
          Text(
            '${AppConstants.currencySymbol}${delta.abs().toStringAsFixed(2)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: arrowColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
