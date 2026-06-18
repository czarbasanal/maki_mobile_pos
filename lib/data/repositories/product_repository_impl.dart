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

  CollectionReference<Map<String, dynamic>> get _skusRef =>
      _firestore.collection(FirestoreCollections.productSkus);

  CollectionReference<Map<String, dynamic>> get _barcodesRef =>
      _firestore.collection(FirestoreCollections.productBarcodes);

  /// The set of claimable barcode keys for a product: trim → drop empty → dedupe.
  /// When [validate], rejects a non-empty code that can't form a claim doc-id.
  Set<String> _barcodeKeys(List<String> codes, {bool validate = false}) {
    final keys = <String>{};
    for (final code in codes) {
      final key = SkuGenerator.normalizeBarcode(code);
      if (key.isEmpty) continue;
      if (validate && !SkuGenerator.isClaimableBarcode(key)) {
        throw ValidationException(
          message: 'Invalid barcode "$code" — cannot contain "/".',
          code: 'invalid-barcode',
        );
      }
      keys.add(key);
    }
    return keys;
  }

  // ==================== CREATE ====================

  @override
  Future<ProductEntity> createProduct({
    required ProductEntity product,
    required String createdBy,
    String? createdByName,
  }) async {
    try {
      // The SKU becomes a product_skus claim doc-id (key = normalizeSku(sku)).
      // Firestore doc-ids forbid '/' and empty strings, so an invalid SKU would
      // crash the claim transaction with an opaque path error. Reject it up
      // front with a clear message — the form validates too, but programmatic
      // callers (batch import) may not. isValidSku enforces non-empty +
      // [A-Za-z0-9-] only, a strict subset of valid doc-ids.
      if (!SkuGenerator.isValidSku(SkuGenerator.normalizeSku(product.sku))) {
        throw ValidationException(
          message:
              'Invalid SKU "${product.sku}" — use letters, numbers, and hyphens only.',
          code: 'invalid-sku',
        );
      }

      // Claimable barcode keys (optional, trimmed, deduped, validated).
      final barcodeKeys = _barcodeKeys(product.barcodes, validate: true);

      final productModel = ProductModel.fromEntity(product);
      final docRef = _productsRef.doc(); // pre-allocate id for the transaction
      final claimRef = _skusRef.doc(SkuGenerator.normalizeSku(product.sku));
      final barcodeRefs = barcodeKeys.map(_barcodesRef.doc).toList();

      // Atomically reserve the SKU + barcode claims and write the product
      // together. Reads precede writes (Firestore transaction rule); the tx.get
      // gates + auto-retry close the TOCTOU the old exists()-then-write left open.
      await _firestore.runTransaction((tx) async {
        final claim = await tx.get(claimRef);
        final barcodeClaims = [for (final ref in barcodeRefs) await tx.get(ref)];
        if (claim.exists) {
          throw DuplicateSkuException(sku: product.sku);
        }
        for (var i = 0; i < barcodeClaims.length; i++) {
          if (barcodeClaims[i].exists) {
            throw DuplicateBarcodeException(barcode: barcodeRefs[i].id);
          }
        }
        tx.set(
          docRef,
          productModel.toCreateMap(createdBy,
              createdByDisplayName: createdByName),
        );
        tx.set(claimRef, {
          'sku': product.sku,
          'productId': docRef.id,
          'claimedBy': createdBy,
          'claimedAt': FieldValue.serverTimestamp(),
        });
        for (final ref in barcodeRefs) {
          tx.set(ref, {
            'barcode': ref.id,
            'productId': docRef.id,
            'claimedBy': createdBy,
            'claimedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // Initial price history — best-effort (unchanged). A failure here must not
      // abort or roll back the already-committed product+claim.
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
      // Primary: array-contains on the new `barcodes` field.
      var snapshot = await _productsRef
          .where('barcodes', arrayContains: barcode)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ProductModel.fromFirestore(snapshot.docs.first).toEntity();
      }

      // Legacy fallback: docs that haven't been re-saved since the
      // schema migration still carry the singular `barcode` String.
      // [ProductModel.fromMap] lifts that into the `barcodes` list at
      // read time, but the Firestore query above won't match it.
      snapshot = await _productsRef
          .where('barcode', isEqualTo: barcode)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ProductModel.fromFirestore(snapshot.docs.first).toEntity();
      }

      // Last fall back: treat the scanned code as a SKU.
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
    String? updatedByName,
  }) async {
    try {
      // Capture prior cost/price before the update so we can detect a change
      // and append a price_history entry below.
      final prior = await getProductById(product.id);

      final productModel = ProductModel.fromEntity(product);
      final updateMap = productModel.toUpdateMap(
        updatedBy,
        updatedByDisplayName: updatedByName,
      );

      final skuChanged = prior != null && prior.sku != product.sku;
      final priorKeys = _barcodeKeys(prior?.barcodes ?? const []);
      final newKeys = _barcodeKeys(product.barcodes, validate: true);
      final addedKeys = newKeys.difference(priorKeys);
      final removedKeys = priorKeys.difference(newKeys);
      final barcodesChanged = addedKeys.isNotEmpty || removedKeys.isNotEmpty;

      if (skuChanged || barcodesChanged) {
        // Variation children (baseSku == old) must be read OUTSIDE the
        // transaction — Firestore transactions cannot run queries.
        final children = skuChanged
            ? await _productsRef.where('baseSku', isEqualTo: prior.sku).get()
            : null;
        final newSkuClaimRef =
            _skusRef.doc(SkuGenerator.normalizeSku(product.sku));
        final addedRefs = addedKeys.map(_barcodesRef.doc).toList();

        // Move the SKU claim (if renamed) + relink variation children, AND
        // release removed / claim added barcodes — all atomically. Reads
        // precede writes (Firestore transaction rule).
        await _firestore.runTransaction((tx) async {
          // Reads.
          final newSkuClaim =
              skuChanged ? await tx.get(newSkuClaimRef) : null;
          final addedClaims = [for (final ref in addedRefs) await tx.get(ref)];
          // Conflict checks.
          if (skuChanged &&
              newSkuClaim!.exists &&
              newSkuClaim.data()?['productId'] != product.id) {
            throw DuplicateSkuException(sku: product.sku);
          }
          for (var i = 0; i < addedClaims.length; i++) {
            final c = addedClaims[i];
            if (c.exists && c.data()?['productId'] != product.id) {
              throw DuplicateBarcodeException(barcode: addedRefs[i].id);
            }
          }
          // Writes.
          tx.update(_productsRef.doc(product.id), updateMap);
          if (skuChanged) {
            for (final child in children!.docs) {
              tx.update(child.reference, {
                'baseSku': product.sku,
                'updatedAt': FieldValue.serverTimestamp(),
                'updatedBy': updatedBy,
                if (updatedByName != null) 'updatedByName': updatedByName,
              });
            }
            // delete-then-set is safe even if old == new (case-only rename):
            // same ref → the set wins, re-keying the claim's sku field.
            tx.delete(_skusRef.doc(SkuGenerator.normalizeSku(prior.sku)));
            tx.set(newSkuClaimRef, {
              'sku': product.sku,
              'productId': product.id,
              'claimedBy': updatedBy,
              'claimedAt': FieldValue.serverTimestamp(),
            });
          }
          for (final key in removedKeys) {
            tx.delete(_barcodesRef.doc(key));
          }
          for (final ref in addedRefs) {
            tx.set(ref, {
              'barcode': ref.id,
              'productId': product.id,
              'claimedBy': updatedBy,
              'claimedAt': FieldValue.serverTimestamp(),
            });
          }
        });
      } else {
        await _productsRef.doc(product.id).update(updateMap);
      }

      final updated = await getProductById(product.id);
      if (updated == null) {
        throw const DatabaseException(
            message: 'Product not found after update');
      }

      if (prior != null) {
        final costChanged = (prior.cost - updated.cost).abs() > 0.01;
        final priceChanged = (prior.price - updated.price).abs() > 0.01;
        if (costChanged || priceChanged) {
          final reason = (costChanged && priceChanged)
              ? 'Price + cost update'
              : (costChanged
                  ? PriceChangeReason.costUpdate
                  : PriceChangeReason.priceUpdate);
          try {
            await recordPriceChange(
              productId: updated.id,
              price: updated.price,
              cost: updated.cost,
              changedBy: updatedBy,
              reason: reason,
            );
          } catch (_) {
            // History is best-effort — don't fail the product update.
          }
        }
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
    String? updatedByName,
  }) async {
    try {
      await _productsRef.doc(productId).update({
        'quantity': FieldValue.increment(quantityChange),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
        if (updatedByName != null) 'updatedByName': updatedByName,
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
    String? updatedByName,
  }) async {
    try {
      await _productsRef.doc(productId).update({
        'quantity': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
        if (updatedByName != null) 'updatedByName': updatedByName,
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
    String? updatedByName,
  }) async {
    try {
      await _productsRef.doc(productId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
        if (updatedByName != null) 'updatedByName': updatedByName,
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
    String? updatedByName,
  }) async {
    try {
      await _productsRef.doc(productId).update({
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
        if (updatedByName != null) 'updatedByName': updatedByName,
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
    String? createdByName,
  }) async {
    try {
      final baseSku = originalProduct.baseSku ?? originalProduct.sku;
      const maxAttempts = 5;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
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
          // A cost-variation is an internal product; the manufacturer barcode
          // stays with the base item, so the variation claims none.
          barcodes: const [],
        );

        try {
          return await createProduct(
            product: variation,
            createdBy: createdBy,
            createdByName: createdByName,
          );
        } on DuplicateSkuException {
          // A concurrent writer claimed this variation number; once their
          // product commits, getNextVariationNumber advances. Recompute & retry.
        }
      }
      throw DatabaseException(
        message:
            'Could not allocate a unique variation SKU for "$baseSku" after $maxAttempts attempts',
      );
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
    String? note,
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
        'note': note,
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
          note: data['note'] as String?,
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
      final snap = await _skusRef.doc(SkuGenerator.normalizeSku(sku)).get();
      if (!snap.exists) return false;
      if (excludeProductId == null) return true;
      return snap.data()?['productId'] != excludeProductId;
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
      // Claim-backed (Slice B): a barcode is taken iff its product_barcodes
      // claim doc exists. Mirrors skuExists.
      final snap =
          await _barcodesRef.doc(SkuGenerator.normalizeBarcode(barcode)).get();
      if (!snap.exists) return false;
      if (excludeProductId == null) return true;
      return snap.data()?['productId'] != excludeProductId;
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

}
