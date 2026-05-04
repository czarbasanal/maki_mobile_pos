import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/utils/sku_generator.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';

/// Firestore implementation of [ProductRepository].
class ProductRepositoryImpl implements ProductRepository {
  final FirebaseFirestore _firestore;

  ProductRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection(FirestoreCollections.products);

  // ==================== CREATE ====================

  @override
  Future<ProductEntity> createProduct({
    required ProductEntity product,
    required String createdBy,
  }) async {
    try {
      // Check for duplicate SKU
      if (await skuExists(sku: product.sku)) {
        throw DuplicateSkuException(sku: product.sku);
      }

      // Check for duplicate barcode if provided
      if (product.barcode != null &&
          product.barcode!.isNotEmpty &&
          await barcodeExists(barcode: product.barcode!)) {
        throw const DuplicateEntryException(
          field: 'barcode',
          value: 'barcode',
          message: 'A product with this barcode already exists',
        );
      }

      final productModel = ProductModel.fromEntity(product);
      final docRef =
          await _productsRef.add(productModel.toCreateMap(createdBy));

      // Initial price history — best-effort. If the price_history subcollection
      // write fails (rules / transient), the product itself has already been
      // created and we'd rather return the new doc than abort and orphan it.
      try {
        await recordPriceChange(
          productId: docRef.id,
          price: product.price,
          cost: product.cost,
          changedBy: createdBy,
          reason: 'Initial price',
        );
      } catch (_) {
        // Swallowed by design.
      }

      return product.copyWith(id: docRef.id);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create product: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== READ ====================

  @override
  Future<ProductEntity?> getProductById(String productId) async {
    try {
      final doc = await _productsRef.doc(productId).get();
      if (!doc.exists) return null;
      return ProductModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get product: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<ProductEntity?> getProductBySku(String sku) async {
    try {
      final snapshot = await _productsRef
          .where('sku', isEqualTo: sku)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return ProductModel.fromFirestore(snapshot.docs.first).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get product by SKU: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<ProductEntity?> getProductByBarcode(String barcode) async {
    try {
      // First try barcode field
      var snapshot = await _productsRef
          .where('barcode', isEqualTo: barcode)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ProductModel.fromFirestore(snapshot.docs.first).toEntity();
      }

      // Fall back to SKU
      return getProductBySku(barcode);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get product by barcode: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<ProductEntity>> getProducts({
    int limit = 50,
    String? startAfterProductId,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _productsRef
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .limit(limit);

      if (startAfterProductId != null) {
        final startAfterDoc = await _productsRef.doc(startAfterProductId).get();
        if (startAfterDoc.exists) {
          query = query.startAfterDocument(startAfterDoc);
        }
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get products: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<ProductEntity>> getAllProducts({
    bool includeInactive = false,
    int limit = 100,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _productsRef.orderBy('name');

      if (!includeInactive) {
        query = query.where('isActive', isEqualTo: true);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get all products: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<ProductEntity>> searchProducts({
    required String query,
    int limit = 20,
  }) async {
    try {
      if (query.isEmpty) return [];

      final searchTerms = query.toLowerCase().split(' ');

      // Search using searchKeywords array
      final snapshot = await _productsRef
          .where('isActive', isEqualTo: true)
          .where('searchKeywords', arrayContainsAny: searchTerms)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to search products: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<ProductEntity>> getProductsBySupplier({
    required String supplierId,
    bool activeOnly = true,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _productsRef.where('supplierId', isEqualTo: supplierId);

      if (activeOnly) {
        query = query.where('isActive', isEqualTo: true);
      }

      final snapshot = await query.orderBy('name').get();
      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get products by supplier: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<ProductEntity>> getProductsByCategory({
    required String category,
    bool activeOnly = true,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _productsRef.where('category', isEqualTo: category);

      if (activeOnly) {
        query = query.where('isActive', isEqualTo: true);
      }

      final snapshot = await query.orderBy('name').get();
      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get products by category: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<ProductEntity>> getLowStockProducts() async {
    try {
      // Firestore doesn't support <= with dynamic field comparison
      // So we get all active products and filter in memory
      final snapshot = await _productsRef
          .where('isActive', isEqualTo: true)
          .orderBy('quantity')
          .get();

      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc).toEntity())
          .where((product) => product.isLowStock)
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get low stock products: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<ProductEntity>> getOutOfStockProducts() async {
    try {
      final snapshot = await _productsRef
          .where('isActive', isEqualTo: true)
          .where('quantity', isLessThanOrEqualTo: 0)
          .get();

      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get out of stock products: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Stream<List<ProductEntity>> watchProducts() {
    return _productsRef
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProductModel.fromFirestore(doc).toEntity())
            .toList());
  }

  @override
  Stream<ProductEntity?> watchProduct(String productId) {
    return _productsRef.doc(productId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ProductModel.fromFirestore(doc).toEntity();
    });
  }

  @override
  Stream<List<ProductEntity>> watchLowStockProducts() {
    return _productsRef
        .where('isActive', isEqualTo: true)
        .orderBy('quantity')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProductModel.fromFirestore(doc).toEntity())
            .where((product) => product.isLowStock)
            .toList());
  }

  // ==================== UPDATE ====================

  @override
  Future<ProductEntity> updateProduct({
    required ProductEntity product,
    required String updatedBy,
  }) async {
    try {
      final productModel = ProductModel.fromEntity(product);
      await _productsRef
          .doc(product.id)
          .update(productModel.toUpdateMap(updatedBy));

      final updated = await getProductById(product.id);
      if (updated == null) {
        throw const DatabaseException(
            message: 'Product not found after update');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update product: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<ProductEntity> updateStock({
    required String productId,
    required int quantityChange,
    required String updatedBy,
  }) async {
    try {
      await _productsRef.doc(productId).update({
        'quantity': FieldValue.increment(quantityChange),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });

      final updated = await getProductById(productId);
      if (updated == null) {
        throw const DatabaseException(
            message: 'Product not found after stock update');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update stock: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<ProductEntity> setStock({
    required String productId,
    required int newQuantity,
    required String updatedBy,
  }) async {
    try {
      await _productsRef.doc(productId).update({
        'quantity': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });

      final updated = await getProductById(productId);
      if (updated == null) {
        throw const DatabaseException(
            message: 'Product not found after stock set');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to set stock: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> deactivateProduct({
    required String productId,
    required String updatedBy,
  }) async {
    try {
      await _productsRef.doc(productId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to deactivate product: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> reactivateProduct({
    required String productId,
    required String updatedBy,
  }) async {
    try {
      await _productsRef.doc(productId).update({
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to reactivate product: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== SKU VARIATION ====================

  @override
  Future<List<ProductEntity>> getSkuVariations(String baseSku) async {
    // Returns the parent (if found) plus every variation that points back to
    // it via the baseSku field. We explicitly avoid SKU prefix matching \u2014
    // SKUs like `rs8-001` would otherwise be mis-parsed as `rs8` + variation
    // suffix `001` and pollute the result set.
    try {
      final variationsFuture = _productsRef
          .where('isActive', isEqualTo: true)
          .where('baseSku', isEqualTo: baseSku)
          .get();
      final parentFuture = _productsRef
          .where('isActive', isEqualTo: true)
          .where('sku', isEqualTo: baseSku)
          .limit(1)
          .get();

      final results = await Future.wait([variationsFuture, parentFuture]);

      return [
        ...results[0].docs,
        ...results[1].docs,
      ].map((doc) => ProductModel.fromFirestore(doc).toEntity()).toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get SKU variations: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<ProductEntity> createVariation({
    required ProductEntity originalProduct,
    required double newCost,
    required String newCostCode,
    required String createdBy,
  }) async {
    try {
      final baseSku = originalProduct.baseSku ?? originalProduct.sku;
      final variationNum = await getNextVariationNumber(baseSku);
      final newSku = SkuGenerator.generateVariation(baseSku, variationNum);

      final variation = originalProduct.copyWith(
        id: '',
        sku: newSku,
        cost: newCost,
        costCode: newCostCode,
        quantity: 0,
        baseSku: baseSku,
        variationNumber: variationNum,
        createdBy: createdBy,
        updatedBy: null,
        updatedAt: null,
      );

      return createProduct(product: variation, createdBy: createdBy);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create variation: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<int> getNextVariationNumber(String baseSku) async {
    // Derive from the structured `variationNumber` field rather than parsing
    // SKU strings — embedded numeric segments (e.g. `rs8-001`) make string
    // parsing unreliable.
    final snapshot = await _productsRef
        .where('baseSku', isEqualTo: baseSku)
        .get();
    var maxVariation = 0;
    for (final doc in snapshot.docs) {
      final n = (doc.data()['variationNumber'] as num?)?.toInt() ?? 0;
      if (n > maxVariation) maxVariation = n;
    }
    return maxVariation + 1;
  }

  // ==================== PRICE HISTORY ====================

  @override
  Future<void> recordPriceChange({
    required String productId,
    required double price,
    required double cost,
    required String changedBy,
    String? reason,
  }) async {
    try {
      final historyRef = _productsRef
          .doc(productId)
          .collection(FirestoreCollections.priceHistory);

      await historyRef.add({
        'price': price,
        'cost': cost,
        'changedAt': FieldValue.serverTimestamp(),
        'changedBy': changedBy,
        'reason': reason,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to record price change: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<PriceHistoryEntry>> getPriceHistory({
    required String productId,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _productsRef
          .doc(productId)
          .collection(FirestoreCollections.priceHistory)
          .orderBy('changedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return PriceHistoryEntry(
          id: doc.id,
          price: (data['price'] as num?)?.toDouble() ?? 0,
          cost: (data['cost'] as num?)?.toDouble() ?? 0,
          changedAt:
              (data['changedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          changedBy: data['changedBy'] as String? ?? '',
          reason: data['reason'] as String?,
        );
      }).toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get price history: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== UTILITY ====================

  @override
  Future<bool> skuExists({
    required String sku,
    String? excludeProductId,
  }) async {
    try {
      final snapshot =
          await _productsRef.where('sku', isEqualTo: sku).limit(2).get();

      if (excludeProductId == null) {
        return snapshot.docs.isNotEmpty;
      }

      return snapshot.docs.any((doc) => doc.id != excludeProductId);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to check SKU existence: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<bool> barcodeExists({
    required String barcode,
    String? excludeProductId,
  }) async {
    try {
      final snapshot = await _productsRef
          .where('barcode', isEqualTo: barcode)
          .limit(2)
          .get();

      if (excludeProductId == null) {
        return snapshot.docs.isNotEmpty;
      }

      return snapshot.docs.any((doc) => doc.id != excludeProductId);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to check barcode existence: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<int> getProductCount({bool activeOnly = true}) async {
    try {
      Query<Map<String, dynamic>> query = _productsRef;

      if (activeOnly) {
        query = query.where('isActive', isEqualTo: true);
      }

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get product count: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<double> getTotalInventoryValueAtCost() async {
    final products = await getAllProducts();
    return products.fold<double>(0.0, (sum, p) => sum + p.inventoryValueAtCost);
  }

  @override
  Future<double> getTotalInventoryValueAtPrice() async {
    final products = await getAllProducts();
    return products.fold<double>(
        0.0, (sum, p) => sum + p.inventoryValueAtPrice);
  }

  @override
  Future<List<String>> getCategories() async {
    try {
      final snapshot = await _productsRef
          .where('isActive', isEqualTo: true)
          .where('category', isNull: false)
          .get();

      final categories = snapshot.docs
          .map((doc) => doc.data()['category'] as String?)
          .where((c) => c != null && c.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      categories.sort();
      return categories;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get categories: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
}
