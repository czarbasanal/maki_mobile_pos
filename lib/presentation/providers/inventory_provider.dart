import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

// ==================== INVENTORY STATE ====================

/// State for inventory screen filters and settings.
class InventoryState {
  final String searchQuery;
  final String? categoryFilter;
  final StockFilter stockFilter;
  final bool showCost;
  final InventorySortOption sortOption;
  final bool sortAscending;

  const InventoryState({
    this.searchQuery = '',
    this.categoryFilter,
    this.stockFilter = StockFilter.all,
    this.showCost = false,
    this.sortOption = InventorySortOption.name,
    this.sortAscending = true,
  });

  InventoryState copyWith({
    String? searchQuery,
    String? categoryFilter,
    StockFilter? stockFilter,
    bool? showCost,
    InventorySortOption? sortOption,
    bool? sortAscending,
    bool clearCategoryFilter = false,
  }) {
    return InventoryState(
      searchQuery: searchQuery ?? this.searchQuery,
      categoryFilter:
          clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
      stockFilter: stockFilter ?? this.stockFilter,
      showCost: showCost ?? this.showCost,
      sortOption: sortOption ?? this.sortOption,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}

/// Stock level filter options.
enum StockFilter {
  all('All'),
  inStock('In Stock'),
  lowStock('Low Stock'),
  outOfStock('Out of Stock');

  final String label;
  const StockFilter(this.label);
}

/// Sort options for inventory.
enum InventorySortOption {
  name('Name'),
  sku('SKU'),
  quantity('Quantity'),
  price('Price'),
  recentlyUpdated('Recently Updated');

  final String label;
  const InventorySortOption(this.label);
}

// ==================== INVENTORY NOTIFIER ====================

/// Manages inventory screen state.
class InventoryNotifier extends StateNotifier<InventoryState> {
  InventoryNotifier() : super(const InventoryState());

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCategoryFilter(String? category) {
    state = state.copyWith(
      categoryFilter: category,
      clearCategoryFilter: category == null,
    );
  }

  void setStockFilter(StockFilter filter) {
    state = state.copyWith(stockFilter: filter);
  }

  void toggleCostVisibility(bool show) {
    state = state.copyWith(showCost: show);
  }

  void setSortOption(InventorySortOption option) {
    if (state.sortOption == option) {
      // Toggle direction if same option
      state = state.copyWith(sortAscending: !state.sortAscending);
    } else {
      state = state.copyWith(sortOption: option, sortAscending: true);
    }
  }

  void resetFilters() {
    state = const InventoryState();
  }
}

/// Provider for inventory state.
final inventoryStateProvider =
    StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  return InventoryNotifier();
});

// ==================== FILTERED PRODUCTS ====================

/// Provides filtered and sorted products based on inventory state.
final filteredProductsProvider =
    Provider<AsyncValue<List<ProductEntity>>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  final inventoryState = ref.watch(inventoryStateProvider);

  return productsAsync.when(
    data: (products) {
      var filtered = products.toList();

      // Apply search filter
      if (inventoryState.searchQuery.isNotEmpty) {
        final query = inventoryState.searchQuery.toLowerCase();
        filtered = filtered.where((p) {
          return p.name.toLowerCase().contains(query) ||
              p.sku.toLowerCase().contains(query) ||
              (p.barcode?.toLowerCase().contains(query) ?? false);
        }).toList();
      }

      // Apply category filter
      if (inventoryState.categoryFilter != null) {
        filtered = filtered
            .where((p) => p.category == inventoryState.categoryFilter)
            .toList();
      }

      // Apply stock filter
      switch (inventoryState.stockFilter) {
        case StockFilter.all:
          break;
        case StockFilter.inStock:
          filtered =
              filtered.where((p) => p.quantity > p.reorderLevel).toList();
          break;
        case StockFilter.lowStock:
          filtered =
              filtered.where((p) => p.isLowStock && !p.isOutOfStock).toList();
          break;
        case StockFilter.outOfStock:
          filtered = filtered.where((p) => p.isOutOfStock).toList();
          break;
      }

      // Apply sorting
      filtered.sort((a, b) {
        int comparison;
        switch (inventoryState.sortOption) {
          case InventorySortOption.name:
            comparison = a.name.compareTo(b.name);
            break;
          case InventorySortOption.sku:
            comparison = a.sku.compareTo(b.sku);
            break;
          case InventorySortOption.quantity:
            comparison = a.quantity.compareTo(b.quantity);
            break;
          case InventorySortOption.price:
            comparison = a.price.compareTo(b.price);
            break;
          case InventorySortOption.recentlyUpdated:
            final aDate = a.updatedAt ?? a.createdAt;
            final bDate = b.updatedAt ?? b.createdAt;
            comparison = bDate.compareTo(aDate); // Newest first
            break;
        }
        return inventoryState.sortAscending ? comparison : -comparison;
      });

      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// ==================== INVENTORY SUMMARY ====================

/// Summary of inventory statistics.
class InventorySummary {
  final int totalProducts;
  final int inStockCount;
  final int lowStockCount;
  final int outOfStockCount;
  final double totalValueAtCost;
  final double totalValueAtPrice;

  const InventorySummary({
    required this.totalProducts,
    required this.inStockCount,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.totalValueAtCost,
    required this.totalValueAtPrice,
  });

  double get potentialProfit => totalValueAtPrice - totalValueAtCost;
}

/// Provides inventory summary statistics.
final inventorySummaryProvider = Provider<AsyncValue<InventorySummary>>((ref) {
  final productsAsync = ref.watch(productsProvider);

  return productsAsync.when(
    data: (products) {
      int inStock = 0;
      int lowStock = 0;
      int outOfStock = 0;
      double valueAtCost = 0;
      double valueAtPrice = 0;

      for (final product in products) {
        if (product.isOutOfStock) {
          outOfStock++;
        } else if (product.isLowStock) {
          lowStock++;
        } else {
          inStock++;
        }
        valueAtCost += product.inventoryValueAtCost;
        valueAtPrice += product.inventoryValueAtPrice;
      }

      return AsyncValue.data(InventorySummary(
        totalProducts: products.length,
        inStockCount: inStock,
        lowStockCount: lowStock,
        outOfStockCount: outOfStock,
        totalValueAtCost: valueAtCost,
        totalValueAtPrice: valueAtPrice,
      ));
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});
