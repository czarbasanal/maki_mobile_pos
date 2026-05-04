import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
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
            icon: const Icon(CupertinoIcons.arrow_up_arrow_down),
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
                            ? CupertinoIcons.arrow_up
                            : CupertinoIcons.arrow_down,
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
              const PopupMenuItem(
                value: 'add',
                child: ListTile(
                  leading: Icon(CupertinoIcons.add),
                  title: Text('Add Product'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(CupertinoIcons.cloud_upload),
                  title: Text('Import CSV'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(CupertinoIcons.cloud_download),
                  title: Text('Export'),
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

          // Product list
          Expanded(
            child: _buildProductList(inventoryState),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _handleMenuAction('add'),
            icon: const Icon(CupertinoIcons.add),
            label: const Text('Add Product'),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    final summaryAsync = ref.watch(inventorySummaryProvider);
    final state = ref.watch(inventoryStateProvider);

    return summaryAsync.when(
      data: (summary) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total',
                '${summary.totalProducts}',
                CupertinoIcons.cube_box,
                AppColors.info,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildSummaryCard(
                'In Stock',
                '${summary.inStockCount}',
                CupertinoIcons.checkmark_circle,
                AppColors.success,
                onTap: () => _setStockFilter(StockFilter.inStock),
                selected: state.stockFilter == StockFilter.inStock,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildSummaryCard(
                'Low',
                '${summary.lowStockCount}',
                CupertinoIcons.exclamationmark_triangle,
                AppColors.warning,
                onTap: () => _setStockFilter(StockFilter.lowStock),
                selected: state.stockFilter == StockFilter.lowStock,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildSummaryCard(
                'Out',
                '${summary.outOfStockCount}',
                CupertinoIcons.exclamationmark_circle,
                AppColors.error,
                onTap: () => _setStockFilter(StockFilter.outOfStock),
                selected: state.stockFilter == StockFilter.outOfStock,
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
    IconData icon,
    Color color, {
    VoidCallback? onTap,
    bool selected = false,
  }) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm + 4,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? color : hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(InventoryState inventoryState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Search field — theme provides muted fill, hairline border,
          // and rounded corners; no overrides needed.
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, SKU, or barcode...',
              prefixIcon: const Icon(CupertinoIcons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(CupertinoIcons.xmark),
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

          const SizedBox(height: 12),

          // Filter chips
          SingleChildScrollView(
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
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip(InventoryState inventoryState) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();

        return PopupMenuButton<String?>(
          child: Chip(
            avatar: const Icon(CupertinoIcons.square_grid_2x2, size: 16),
            label: Text(inventoryState.categoryFilter ?? 'Category'),
            deleteIcon: inventoryState.categoryFilter != null
                ? const Icon(CupertinoIcons.xmark, size: 16)
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
                  value: cat,
                  child: Text(cat),
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
            CupertinoIcons.line_horizontal_3_decrease,
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
              );
            },
          ),
        );
      },
      loading: () => const LoadingView(),
      error: (error, _) => ErrorStateView(
        message: 'Error: $error',
        onRetry: () => ref.invalidate(productsProvider),
      ),
    );
  }

  Widget _buildEmptyState(InventoryState state) {
    final hasFilters = _hasActiveFilters(state);
    return EmptyStateView(
      icon: hasFilters ? Icons.filter_alt_off_outlined : CupertinoIcons.cube_box,
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

  void _handleMenuAction(String action) {
    switch (action) {
      case 'add':
        context.push(RoutePaths.productAdd);
        break;
      case 'import':
        context.showSnackBar('CSV import coming soon');
        break;
      case 'export':
        context.showSnackBar('Export coming soon');
        break;
    }
  }
}

