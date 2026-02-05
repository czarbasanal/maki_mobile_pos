import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository contract for Product operations.
///
/// This interface defines all data access methods for products.
/// Implementations handle the actual data source (Firestore, etc.)
abstract class ProductRepository {
  // ==================== CREATE ====================

  /// Creates a new product and returns it with the generated ID.
  ///
  /// [product] - The product entity to create
  /// [createdBy] - The ID of the user creating the product
  ///
  /// Returns the created product with populated ID.
  /// Throws [DuplicateSkuException] if SKU already exists.
  Future<ProductEntity> createProduct({
    required ProductEntity product,
    required String createdBy,
  });

  // ==================== READ ====================

  /// Retrieves a product by its ID.
  ///
  /// Returns null if not found.
  Future<ProductEntity?> getProductById(String productId);

  /// Retrieves a product by its SKU.
  ///
  /// Returns null if not found.
  Future<ProductEntity?> getProductBySku(String sku);

  /// Retrieves a product by its barcode.
  ///
  /// Returns null if not found.
  Future<ProductEntity?> getProductByBarcode(String barcode);

  /// Retrieves all active products.
  ///
  /// [limit] - Maximum number of products to return
  /// [startAfterProductId] - For pagination
  ///
  /// Returns list of products ordered by name.
  Future<List<ProductEntity>> getProducts({
    int limit = 50,
    String? startAfterProductId,
  });

  /// Retrieves all products including inactive ones.
  ///
  /// [includeInactive] - Whether to include inactive products
  /// [limit] - Maximum number of products to return
  Future<List<ProductEntity>> getAllProducts({
    bool includeInactive = false,
    int limit = 100,
  });

  /// Searches products by name, SKU, or barcode.
  ///
  /// [query] - Search query string
  /// [limit] - Maximum number of results
  ///
  /// Returns list of matching products.
  Future<List<ProductEntity>> searchProducts({
    required String query,
    int limit = 20,
  });

  /// Retrieves products by supplier.
  ///
  /// [supplierId] - The supplier's ID
  /// [activeOnly] - Whether to return only active products
  Future<List<ProductEntity>> getProductsBySupplier({
    required String supplierId,
    bool activeOnly = true,
  });

  /// Retrieves products by category.
  ///
  /// [category] - The category name
  /// [activeOnly] - Whether to return only active products
  Future<List<ProductEntity>> getProductsByCategory({
    required String category,
    bool activeOnly = true,
  });

  /// Retrieves low stock products.
  ///
  /// Returns products where quantity <= reorderLevel.
  Future<List<ProductEntity>> getLowStockProducts();

  /// Retrieves out of stock products.
  ///
  /// Returns products where quantity <= 0.
  Future<List<ProductEntity>> getOutOfStockProducts();

  /// Streams all active products for real-time updates.
  Stream<List<ProductEntity>> watchProducts();

  /// Streams a single product for real-time updates.
  Stream<ProductEntity?> watchProduct(String productId);

  /// Streams low stock products for real-time alerts.
  Stream<List<ProductEntity>> watchLowStockProducts();

  // ==================== UPDATE ====================

  /// Updates an existing product.
  ///
  /// [product] - The product with updated values
  /// [updatedBy] - The ID of the user making the update
  ///
  /// Returns the updated product.
  Future<ProductEntity> updateProduct({
    required ProductEntity product,
    required String updatedBy,
  });

  /// Updates product stock quantity.
  ///
  /// [productId] - The product ID
  /// [quantityChange] - Amount to add (positive) or remove (negative)
  /// [updatedBy] - The ID of the user making the update
  ///
  /// Returns the updated product.
  Future<ProductEntity> updateStock({
    required String productId,
    required int quantityChange,
    required String updatedBy,
  });

  /// Sets product stock to a specific quantity.
  ///
  /// [productId] - The product ID
  /// [newQuantity] - The new stock quantity
  /// [updatedBy] - The ID of the user making the update
  ///
  /// Returns the updated product.
  Future<ProductEntity> setStock({
    required String productId,
    required int newQuantity,
    required String updatedBy,
  });

  /// Deactivates a product (soft delete).
  ///
  /// [productId] - The product ID
  /// [updatedBy] - The ID of the user making the update
  Future<void> deactivateProduct({
    required String productId,
    required String updatedBy,
  });

  /// Reactivates a product.
  ///
  /// [productId] - The product ID
  /// [updatedBy] - The ID of the user making the update
  Future<void> reactivateProduct({
    required String productId,
    required String updatedBy,
  });

  // ==================== SKU VARIATION ====================

  /// Gets all variations of a product.
  ///
  /// [baseSku] - The base SKU to find variations for
  ///
  /// Returns list of all SKU variations (including original).
  Future<List<ProductEntity>> getSkuVariations(String baseSku);

  /// Creates a variation of an existing product.
  ///
  /// Used when receiving stock with same SKU but different cost.
  ///
  /// [originalProduct] - The original product
  /// [newCost] - The new cost for this variation
  /// [newCostCode] - The encoded cost code
  /// [createdBy] - The ID of the user creating the variation
  ///
  /// Returns the new variation product with incremented SKU (e.g., ABC-1, ABC-2).
  Future<ProductEntity> createVariation({
    required ProductEntity originalProduct,
    required double newCost,
    required String newCostCode,
    required String createdBy,
  });

  /// Gets the next variation number for a SKU.
  ///
  /// [baseSku] - The base SKU
  ///
  /// Returns the next available variation number.
  Future<int> getNextVariationNumber(String baseSku);

  // ==================== PRICE HISTORY ====================

  /// Records a price/cost change in history.
  ///
  /// [productId] - The product ID
  /// [price] - The new price
  /// [cost] - The new cost
  /// [changedBy] - The ID of the user making the change
  /// [reason] - Reason for the change
  Future<void> recordPriceChange({
    required String productId,
    required double price,
    required double cost,
    required String changedBy,
    String? reason,
  });

  /// Gets price history for a product.
  ///
  /// [productId] - The product ID
  /// [limit] - Maximum number of history entries
  ///
  /// Returns list of price history entries, newest first.
  Future<List<PriceHistoryEntry>> getPriceHistory({
    required String productId,
    int limit = 50,
  });

  // ==================== UTILITY ====================

  /// Checks if a SKU already exists.
  ///
  /// [sku] - The SKU to check
  /// [excludeProductId] - Optional product ID to exclude (for updates)
  Future<bool> skuExists({
    required String sku,
    String? excludeProductId,
  });

  /// Checks if a barcode already exists.
  ///
  /// [barcode] - The barcode to check
  /// [excludeProductId] - Optional product ID to exclude (for updates)
  Future<bool> barcodeExists({
    required String barcode,
    String? excludeProductId,
  });

  /// Gets total product count.
  ///
  /// [activeOnly] - Whether to count only active products
  Future<int> getProductCount({bool activeOnly = true});

  /// Gets total inventory value at cost.
  Future<double> getTotalInventoryValueAtCost();

  /// Gets total inventory value at price.
  Future<double> getTotalInventoryValueAtPrice();

  /// Gets all unique categories.
  Future<List<String>> getCategories();
}

/// Represents a price history entry.
class PriceHistoryEntry {
  final String id;
  final double price;
  final double cost;
  final DateTime changedAt;
  final String changedBy;
  final String? reason;

  const PriceHistoryEntry({
    required this.id,
    required this.price,
    required this.cost,
    required this.changedAt,
    required this.changedBy,
    this.reason,
  });
}
