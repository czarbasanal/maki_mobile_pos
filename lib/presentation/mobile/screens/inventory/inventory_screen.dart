import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/inventory_export.dart';
import 'package:maki_mobile_pos/core/utils/report_export.dart';
import 'package:maki_mobile_pos/core/utils/stock_totals.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/inventory_widgets.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Main inventory management screen.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryStateProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    final isAdmin = currentUser?.role == UserRole.admin;
    final canAddProduct =
        currentUser?.hasPermission(Permission.addProduct) ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Inventory'),
        actions: [
          // Cost visibility toggle (admin only; password-confirmed by widget)
          if (isAdmin)
            CostDisplayToggle(
              showCost: inventoryState.showCost,
              onToggle: (show) {
                ref
                    .read(inventoryStateProvider.notifier)
                    .toggleCostVisibility(show);
              },
            ),
          // Sort button
          PopupMenuButton<InventorySortOption>(
            icon: const Icon(LucideIcons.arrowUpDown),
            tooltip: 'Sort by',
            onSelected: (option) {
              ref.read(inventoryStateProvider.notifier).setSortOption(option);
            },
            itemBuilder: (context) => InventorySortOption.values.map((option) {
              final isSelected = inventoryState.sortOption == option;
              return PopupMenuItem(
                value: option,
                child: Row(
                  children: [
                    if (isSelected)
                      Icon(
                        inventoryState.sortAscending
                            ? LucideIcons.arrowUp
                            : LucideIcons.arrowDown,
                        size: 16,
                      )
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Text(option.label),
                  ],
                ),
              );
            }).toList(),
          ),
          // More options
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              if (canAddProduct)
                const PopupMenuItem(
                  value: 'add',
                  child: ListTile(
                    leading: Icon(LucideIcons.plus),
                    title: Text('Add Product'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              if (isAdmin)
                const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(LucideIcons.download),
                    title: Text('Export CSV'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary cards
          _buildSummaryRow(),

          // Search and filters
          _buildSearchAndFilters(inventoryState),

          // Active filters display
          if (_hasActiveFilters(inventoryState))
            _buildActiveFilters(inventoryState),

          // Inventory valuation strip (admin only)
          if (isAdmin) const _InventoryTotalsStrip(),

          // Product list
          Expanded(
            child: _buildProductList(inventoryState),
          ),
        ],
      ),
      bottomNavigationBar: canAddProduct ? _buildAddFooter() : null,
    );
  }

  Widget _buildAddFooter() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: AppShadows.pinnedFooter(dark: isDark),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.field),
            boxShadow: isDark
                ? AppShadows.primaryButtonGold
                : AppShadows.primaryButton,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: () => _handleMenuAction('add'),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Add Product'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    final summaryAsync = ref.watch(inventorySummaryProvider);
    final state = ref.watch(inventoryStateProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Per the prototype the icon and the count can take different hues, and
    // Low/Out lift to lighter tones in dark mode.
    final totalIcon = isDark ? const Color(0xFF5AA9F0) : AppColors.info;
    final inIcon = isDark ? const Color(0xFF5FC86A) : AppColors.success;
    final inValue = AppColors.successText(isDark);
    final low = isDark ? const Color(0xFFF5B547) : AppColors.warningDark;
    final out = isDark ? const Color(0xFFFF6B5E) : AppColors.error;

    return summaryAsync.when(
      data: (summary) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          14,
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total',
                '${summary.totalProducts}',
                LucideIcons.package,
                iconColor: totalIcon,
                valueColor: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildSummaryCard(
                'In Stock',
                '${summary.inStockCount}',
                LucideIcons.checkCircle,
                iconColor: inIcon,
                valueColor: inValue,
                onTap: () => _setStockFilter(StockFilter.inStock),
                selected: state.stockFilter == StockFilter.inStock,
                selectedBorderColor: AppColors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildSummaryCard(
                'Low',
                '${summary.lowStockCount}',
                LucideIcons.alertTriangle,
                iconColor: low,
                valueColor: low,
                onTap: () => _setStockFilter(StockFilter.lowStock),
                selected: state.stockFilter == StockFilter.lowStock,
                selectedBorderColor: low,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildSummaryCard(
                'Out',
                '${summary.outOfStockCount}',
                LucideIcons.alertCircle,
                iconColor: out,
                valueColor: out,
                onTap: () => _setStockFilter(StockFilter.outOfStock),
                selected: state.stockFilter == StockFilter.outOfStock,
                selectedBorderColor: AppColors.error,
              ),
            ),
          ],
        ),
      ),
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon, {
    required Color iconColor,
    required Color valueColor,
    VoidCallback? onTap,
    bool selected = false,
    Color? selectedBorderColor,
  }) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    final card = AppCard(
      radius: AppRadius.md,
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 19),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: muted,
            ),
          ),
        ],
      ),
    );

    if (selected && selectedBorderColor != null) {
      // Paint the selected ring over the card edge without re-deriving the
      // AppCard surface (light shadow / dark hairline).
      return Container(
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selectedBorderColor, width: 1.5),
        ),
        child: card,
      );
    }
    return card;
  }

  Widget _buildSearchAndFilters(InventoryState inventoryState) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Search field on a soft-shadow AppCard pill (borderless field
          // inside so the card is the only surface).
          AppCard(
            radius: AppRadius.field,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              style: AppTextStyles.fieldInput,
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, SKU, or barcode...',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 30, minHeight: 30),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(inventoryStateProvider.notifier)
                              .setSearchQuery('');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                ref.read(inventoryStateProvider.notifier).setSearchQuery(value);
              },
            ),
          ),

          const SizedBox(height: 12),

          // Filter chips — neutralize the chip ink feedback (the global gold
          // `secondary` otherwise tints the tap splash/hover yellow).
          Theme(
            data: theme.copyWith(
              splashColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              highlightColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.04),
              hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.04),
              focusColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Stock filter chips
                  ...StockFilter.values.map((filter) {
                    final isSelected = inventoryState.stockFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter.label),
                        selected: isSelected,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          // Selected sits on a slate(light)/gold(dark) fill, so
                          // the label flips to white(light)/near-black(dark) for
                          // contrast; unselected uses normal ink.
                          color: isSelected
                              ? (isDark ? AppColors.primaryDark : Colors.white)
                              : theme.colorScheme.onSurface,
                        ),
                        selectedColor: isDark
                            ? AppColors.primaryAccent
                            : AppColors.brandSlate,
                        backgroundColor:
                            isDark ? AppColors.darkCard : AppColors.lightCard,
                        side: BorderSide(
                          color: isSelected
                              ? Colors.transparent
                              : (isDark
                                  ? AppColors.darkHairline
                                  : AppColors.lightHairline),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        onSelected: (selected) {
                          ref
                              .read(inventoryStateProvider.notifier)
                              .setStockFilter(
                                selected ? filter : StockFilter.all,
                              );
                        },
                      ),
                    );
                  }),

                  const SizedBox(width: 8),

                  // Category filter
                  _buildCategoryFilterChip(inventoryState),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip(InventoryState inventoryState) {
    final categoriesAsync =
        ref.watch(activeCategoriesProvider(CategoryKind.product));

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();

        return PopupMenuButton<String?>(
          child: Chip(
            avatar: const Icon(LucideIcons.layoutGrid, size: 16),
            label: Text(inventoryState.categoryFilter ?? 'Category'),
            deleteIcon: inventoryState.categoryFilter != null
                ? const Icon(LucideIcons.x, size: 16)
                : null,
            onDeleted: inventoryState.categoryFilter != null
                ? () {
                    ref
                        .read(inventoryStateProvider.notifier)
                        .setCategoryFilter(null);
                  }
                : null,
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: null,
              child: Text('All Categories'),
            ),
            ...categories.map((cat) => PopupMenuItem(
                  value: cat.name,
                  child: Text(cat.name),
                )),
          ],
          onSelected: (value) {
            ref.read(inventoryStateProvider.notifier).setCategoryFilter(value);
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildActiveFilters(InventoryState state) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.slidersHorizontal,
            size: 16,
            color: muted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Filters active',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              ref.read(inventoryStateProvider.notifier).resetFilters();
              _searchController.clear();
            },
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(InventoryState inventoryState) {
    final productsAsync = ref.watch(filteredProductsProvider);
    final isAdmin =
        ref.watch(currentUserProvider).value?.role == UserRole.admin;

    return productsAsync.when(
      data: (products) {
        if (products.isEmpty) {
          return _buildEmptyState(inventoryState);
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(productsProvider);
          },
          child: ListView.builder(
            itemCount: products.length,
            padding: const EdgeInsets.only(bottom: 80),
            itemBuilder: (context, index) {
              final product = products[index];
              return ProductListTile(
                product: product,
                showCost: inventoryState.showCost,
                onTap: () => _navigateToProductDetail(product),
                onLongPress:
                    isAdmin ? () => _confirmAndDelete(context, product) : null,
              );
            },
          ),
        );
      },
      loading: () => const ListSkeleton(),
      error: (error, _) => ErrorStateView(
        message: 'Error: $error',
        onRetry: () => ref.invalidate(productsProvider),
      ),
    );
  }

  Widget _buildEmptyState(InventoryState state) {
    final hasFilters = _hasActiveFilters(state);
    return EmptyStateView(
      icon: hasFilters ? LucideIcons.slidersHorizontal : LucideIcons.package,
      title: hasFilters ? 'No products match filters' : 'No Products Yet',
      subtitle: hasFilters
          ? 'Try adjusting your search or filters'
          : 'Add your first product to get started',
      action: hasFilters
          ? OutlinedButton(
              onPressed: () {
                ref.read(inventoryStateProvider.notifier).resetFilters();
                _searchController.clear();
              },
              child: const Text('Clear Filters'),
            )
          : null,
    );
  }

  bool _hasActiveFilters(InventoryState state) {
    return state.searchQuery.isNotEmpty ||
        state.categoryFilter != null ||
        state.stockFilter != StockFilter.all;
  }

  void _setStockFilter(StockFilter filter) {
    final currentFilter = ref.read(inventoryStateProvider).stockFilter;
    ref.read(inventoryStateProvider.notifier).setStockFilter(
          currentFilter == filter ? StockFilter.all : filter,
        );
  }

  void _navigateToProductDetail(ProductEntity product) {
    context.push('${RoutePaths.inventory}/${product.id}');
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    ProductEntity product,
  ) async {
    final confirmed = await context.showConfirmDialog(
      title: 'Delete Product?',
      message: 'Delete "${product.name}"? This product will be hidden from POS '
          'and inventory lists. Past sales and receivings that reference '
          'it remain intact.',
      confirmText: 'Delete',
      icon: LucideIcons.trash2,
      isDangerous: true,
    );
    if (!confirmed) return;

    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    final ok = await ref
        .read(productOperationsProvider.notifier)
        .deactivateProduct(actor: currentUser, productId: product.id);

    if (!context.mounted) return;
    if (ok) {
      context.showSuccessSnackBar('Product deleted');
    } else {
      context.showErrorSnackBar('Failed to delete product');
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'add':
        context.push(RoutePaths.productAdd);
        break;
      case 'export':
        _handleExport();
        break;
    }
  }

  Future<void> _handleExport() async {
    try {
      final products = await ref
          .read(productRepositoryProvider)
          .getAllProducts(includeInactive: true, limit: 100000);

      if (!mounted) return;
      if (products.isEmpty) {
        context.showSnackBar('No products to export');
        return;
      }

      final csv = buildInventoryCsv(products);
      final fileName =
          'inventory_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
      if (!mounted) return;
      await saveReportCsv(context, csv, fileName);
    } catch (e) {
      if (mounted) context.showErrorSnackBar('Export failed: $e');
    }
  }
}

/// Admin-only inventory valuation strip — stock cost, retail value, and
/// expected profit over whatever [filteredProductsProvider] is currently
/// returning (i.e. respects the active search/stock/category filters).
class _InventoryTotalsStrip extends ConsumerWidget {
  const _InventoryTotalsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(filteredProductsProvider).valueOrNull;
    if (products == null || products.isEmpty) return const SizedBox.shrink();

    final totals = StockTotals.of(products);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: AppCard(
        radius: AppRadius.md,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: _TotalsFigure(
                label: 'Stock Cost',
                value: totals.cost.toCurrency(),
              ),
            ),
            Expanded(
              child: _TotalsFigure(
                label: 'Retail Value',
                value: totals.retail.toCurrency(),
              ),
            ),
            Expanded(
              child: _TotalsFigure(
                label: 'Expected Profit',
                value: totals.profit.toCurrency(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One cost/retail/profit figure within [_InventoryTotalsStrip].
class _TotalsFigure extends StatelessWidget {
  const _TotalsFigure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            color: muted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
