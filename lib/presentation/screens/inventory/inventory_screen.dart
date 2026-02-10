import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/widgets/inventory/inventory_widgets.dart';

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
    final theme = Theme.of(context);
    final inventoryState = ref.watch(inventoryStateProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    final isAdmin = currentUser?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Inventory'),
        actions: [
          // Cost visibility toggle (admin only)
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
            icon: const Icon(Icons.sort),
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
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
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
                  leading: Icon(Icons.add),
                  title: Text('Add Product'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.upload_file),
                  title: Text('Import CSV'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _handleMenuAction('add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }

  Widget _buildSummaryRow() {
    final summaryAsync = ref.watch(inventorySummaryProvider);

    return summaryAsync.when(
      data: (summary) => Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total',
                '${summary.totalProducts}',
                Icons.inventory_2,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSummaryCard(
                'In Stock',
                '${summary.inStockCount}',
                Icons.check_circle,
                Colors.green,
                onTap: () => _setStockFilter(StockFilter.inStock),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSummaryCard(
                'Low',
                '${summary.lowStockCount}',
                Icons.warning,
                Colors.orange,
                onTap: () => _setStockFilter(StockFilter.lowStock),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSummaryCard(
                'Out',
                '${summary.outOfStockCount}',
                Icons.error,
                Colors.red,
                onTap: () => _setStockFilter(StockFilter.outOfStock),
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
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
          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, SKU, or barcode...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        ref
                            .read(inventoryStateProvider.notifier)
                            .setSearchQuery('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
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
            avatar: const Icon(Icons.category, size: 16),
            label: Text(inventoryState.categoryFilter ?? 'Category'),
            deleteIcon: inventoryState.categoryFilter != null
                ? const Icon(Icons.close, size: 16)
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          const Text('Filters active'),
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
                onStockAdjust: () => _showStockAdjustment(product),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(productsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(InventoryState state) {
    final hasFilters = _hasActiveFilters(state);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.filter_alt_off : Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No products match filters' : 'No Products Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try adjusting your search or filters'
                  : 'Add your first product to get started',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  ref.read(inventoryStateProvider.notifier).resetFilters();
                  _searchController.clear();
                },
                child: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
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

  void _showStockAdjustment(ProductEntity product) {
    // Will be implemented in stock_adjustment_dialog.dart
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StockAdjustmentSheet(product: product),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'add':
        context.push(RoutePaths.productAdd);
        break;
      case 'import':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV import coming soon')),
        );
        break;
      case 'export':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export coming soon')),
        );
        break;
    }
  }
}

/// Placeholder for stock adjustment - will be replaced
class StockAdjustmentSheet extends StatelessWidget {
  final ProductEntity product;

  const StockAdjustmentSheet({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Adjust Stock: ${product.name}'),
          const SizedBox(height: 16),
          const Text('Full implementation in stock_adjustment_dialog.dart'),
        ],
      ),
    );
  }
}
