import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/data/repositories/product_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';

// ==================== REPOSITORY PROVIDER ====================

/// Provides the ProductRepository instance.
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl();
});

// ==================== PRODUCT QUERIES ====================

/// Provides all active products as a real-time stream.
final productsProvider = StreamProvider<List<ProductEntity>>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  return repository.watchProducts();
});

/// Provides a single product by ID.
final productByIdProvider =
    FutureProvider.family<ProductEntity?, String>((ref, productId) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProductById(productId);
});

/// Provides a single product by ID as a stream.
final productStreamProvider =
    StreamProvider.family<ProductEntity?, String>((ref, productId) {
  final repository = ref.watch(productRepositoryProvider);
  return repository.watchProduct(productId);
});

/// Provides a single product by SKU.
final productBySkuProvider =
    FutureProvider.family<ProductEntity?, String>((ref, sku) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProductBySku(sku);
});

/// Provides a single product by barcode.
final productByBarcodeProvider =
    FutureProvider.family<ProductEntity?, String>((ref, barcode) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProductByBarcode(barcode);
});

/// Provides product search results (Firestore query).
final productSearchProvider =
    FutureProvider.family<List<ProductEntity>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];

  final repository = ref.watch(productRepositoryProvider);
  return repository.searchProducts(query: query, limit: 20);
});

/// Provides instant product search from in-memory data.
/// Falls back to Firestore search if products stream hasn't loaded yet.
final localProductSearchProvider =
    Provider.family<AsyncValue<List<ProductEntity>>, String>((ref, query) {
  if (query.trim().isEmpty) return const AsyncValue.data([]);

  final productsAsync = ref.watch(productsProvider);

  return productsAsync.when(
    data: (products) {
      final searchTerms =
          query.toLowerCase().split(' ').where((s) => s.isNotEmpty).toList();

      final results = products.where((product) {
        final searchable =
            '${product.name} ${product.sku} ${product.barcode ?? ''} ${product.category ?? ''}'
                .toLowerCase();
        return searchTerms.every((term) => searchable.contains(term));
      }).take(20).toList();

      return AsyncValue.data(results);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Provides products by supplier.
final productsBySupplierProvider =
    FutureProvider.family<List<ProductEntity>, String>((ref, supplierId) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProductsBySupplier(supplierId: supplierId);
});

/// Provides products by category.
final productsByCategoryProvider =
    FutureProvider.family<List<ProductEntity>, String>((ref, category) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProductsByCategory(category: category);
});

/// Provides low stock products as a real-time stream.
final lowStockProductsProvider = StreamProvider<List<ProductEntity>>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  return repository.watchLowStockProducts();
});

/// Provides out of stock products.
final outOfStockProductsProvider =
    FutureProvider<List<ProductEntity>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getOutOfStockProducts();
});

/// Provides all categories.
final categoriesProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getCategories();
});

/// Provides product count.
final productCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProductCount();
});

/// Provides total inventory value at cost.
final inventoryValueAtCostProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getTotalInventoryValueAtCost();
});

/// Provides total inventory value at price.
final inventoryValueAtPriceProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getTotalInventoryValueAtPrice();
});

// ==================== PRODUCT OPERATIONS ====================

/// Notifier for product operations (create, update, delete).
class ProductOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final ProductRepository _repository;
  final Ref _ref;

  ProductOperationsNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  /// Creates a new product.
  Future<ProductEntity?> createProduct({
    required ProductEntity product,
    required String createdBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      final created = await _repository.createProduct(
        product: product,
        createdBy: createdBy,
      );
      state = const AsyncValue.data(null);
      _invalidateProductProviders();
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Updates an existing product.
  Future<ProductEntity?> updateProduct({
    required ProductEntity product,
    required String updatedBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _repository.updateProduct(
        product: product,
        updatedBy: updatedBy,
      );
      state = const AsyncValue.data(null);
      _invalidateProductProviders();
      _ref.invalidate(productByIdProvider(product.id));
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Updates product stock.
  Future<ProductEntity?> updateStock({
    required String productId,
    required int quantityChange,
    required String updatedBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _repository.updateStock(
        productId: productId,
        quantityChange: quantityChange,
        updatedBy: updatedBy,
      );
      state = const AsyncValue.data(null);
      _ref.invalidate(productByIdProvider(productId));
      _ref.invalidate(lowStockProductsProvider);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Deactivates a product.
  Future<bool> deactivateProduct({
    required String productId,
    required String updatedBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deactivateProduct(
        productId: productId,
        updatedBy: updatedBy,
      );
      state = const AsyncValue.data(null);
      _invalidateProductProviders();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Creates a SKU variation.
  Future<ProductEntity?> createVariation({
    required ProductEntity originalProduct,
    required double newCost,
    required String newCostCode,
    required String createdBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      final variation = await _repository.createVariation(
        originalProduct: originalProduct,
        newCost: newCost,
        newCostCode: newCostCode,
        createdBy: createdBy,
      );
      state = const AsyncValue.data(null);
      _invalidateProductProviders();
      return variation;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Checks if SKU exists.
  Future<bool> skuExists(String sku, {String? excludeProductId}) async {
    try {
      return await _repository.skuExists(
        sku: sku,
        excludeProductId: excludeProductId,
      );
    } catch (e) {
      return false;
    }
  }

  void _invalidateProductProviders() {
    _ref.invalidate(productsProvider);
    _ref.invalidate(productCountProvider);
    _ref.invalidate(lowStockProductsProvider);
    _ref.invalidate(inventoryValueAtCostProvider);
    _ref.invalidate(inventoryValueAtPriceProvider);
    _ref.invalidate(categoriesProvider);
  }
}

/// Provider for product operations.
final productOperationsProvider =
    StateNotifierProvider<ProductOperationsNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  return ProductOperationsNotifier(repository, ref);
});

// ==================== SELECTED PRODUCT ====================

/// Currently selected product for viewing/editing.
final selectedProductProvider = StateProvider<ProductEntity?>((ref) => null);
