import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/data/repositories/product_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/product/create_product_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/product/deactivate_product_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/product/update_product_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

// ==================== REPOSITORY PROVIDER ====================

/// Provides the ProductRepository instance.
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl();
});

// ==================== PRODUCT QUERIES ====================

/// Provides all active products as a real-time stream.
final productsProvider = StreamProvider<List<ProductEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(productRepositoryProvider).watchProducts();
  });
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
  return authGatedStream(ref, (_) {
    return ref.watch(productRepositoryProvider).watchProduct(productId);
  });
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

/// Provides price history for a product (newest first).
final priceHistoryProvider =
    FutureProvider.family<List<PriceHistoryEntry>, String>(
        (ref, productId) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getPriceHistory(productId: productId);
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
  return authGatedStream(ref, (_) {
    return ref.watch(productRepositoryProvider).watchLowStockProducts();
  });
});

/// Provides out of stock products.
final outOfStockProductsProvider =
    FutureProvider<List<ProductEntity>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getOutOfStockProducts();
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

// ==================== USE CASE PROVIDERS ====================

final createProductUseCaseProvider = Provider<CreateProductUseCase>((ref) {
  return CreateProductUseCase(
    repository: ref.watch(productRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final updateProductUseCaseProvider = Provider<UpdateProductUseCase>((ref) {
  return UpdateProductUseCase(
    repository: ref.watch(productRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

final deactivateProductUseCaseProvider =
    Provider<DeactivateProductUseCase>((ref) {
  return DeactivateProductUseCase(
    repository: ref.watch(productRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});

// ==================== PRODUCT OPERATIONS ====================

/// Notifier for product operations.
///
/// User-facing mutations (create / update / deactivate) flow through use
/// cases that own permission gating (admin vs staff-limited price/cost
/// lock) and audit logging. Internal stock adjustments triggered by
/// process_sale_usecase / void_sale_usecase still call the repo directly
/// — those callers gate the operation upstream.
class ProductOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final ProductRepository _repository;
  final CreateProductUseCase _createUseCase;
  final UpdateProductUseCase _updateUseCase;
  final DeactivateProductUseCase _deactivateUseCase;
  final Ref _ref;

  ProductOperationsNotifier({
    required ProductRepository repository,
    required CreateProductUseCase createUseCase,
    required UpdateProductUseCase updateUseCase,
    required DeactivateProductUseCase deactivateUseCase,
    required Ref ref,
  })  : _repository = repository,
        _createUseCase = createUseCase,
        _updateUseCase = updateUseCase,
        _deactivateUseCase = deactivateUseCase,
        _ref = ref,
        super(const AsyncValue.data(null));

  Future<ProductEntity?> createProduct({
    required UserEntity actor,
    required ProductEntity product,
  }) async {
    state = const AsyncValue.loading();
    final result = await _createUseCase.execute(actor: actor, product: product);
    if (result.success) {
      state = const AsyncValue.data(null);
      _invalidateProductProviders();
      return result.data;
    }
    state = AsyncValue.error(
      result.errorMessage ?? 'Failed to create product',
      StackTrace.current,
    );
    return null;
  }

  Future<ProductEntity?> updateProduct({
    required UserEntity actor,
    required ProductEntity product,
  }) async {
    state = const AsyncValue.loading();
    final result = await _updateUseCase.execute(actor: actor, product: product);
    if (result.success) {
      state = const AsyncValue.data(null);
      _invalidateProductProviders();
      _ref.invalidate(productByIdProvider(product.id));
      return result.data;
    }
    state = AsyncValue.error(
      result.errorMessage ?? 'Failed to update product',
      StackTrace.current,
    );
    return null;
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

  /// Deactivates a product (admin-only via use case).
  Future<bool> deactivateProduct({
    required UserEntity actor,
    required String productId,
  }) async {
    state = const AsyncValue.loading();
    final result =
        await _deactivateUseCase.execute(actor: actor, productId: productId);
    if (result.success) {
      state = const AsyncValue.data(null);
      _invalidateProductProviders();
      return true;
    }
    state = AsyncValue.error(
      result.errorMessage ?? 'Failed to deactivate product',
      StackTrace.current,
    );
    return false;
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
  }
}

/// Provider for product operations.
final productOperationsProvider =
    StateNotifierProvider<ProductOperationsNotifier, AsyncValue<void>>((ref) {
  return ProductOperationsNotifier(
    repository: ref.watch(productRepositoryProvider),
    createUseCase: ref.watch(createProductUseCaseProvider),
    updateUseCase: ref.watch(updateProductUseCaseProvider),
    deactivateUseCase: ref.watch(deactivateProductUseCaseProvider),
    ref: ref,
  );
});

// ==================== SELECTED PRODUCT ====================

/// Currently selected product for viewing/editing.
final selectedProductProvider = StateProvider<ProductEntity?>((ref) => null);
