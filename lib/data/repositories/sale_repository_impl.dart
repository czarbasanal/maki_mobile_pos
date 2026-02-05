import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

/// Firestore implementation of [SaleRepository].
///
/// Data structure:
/// - sales/{saleId} - Sale document
/// - sales/{saleId}/items/{itemId} - Sale items subcollection
/// - settings/sale_counters - Daily sale number counters
class SaleRepositoryImpl implements SaleRepository {
  final FirebaseFirestore _firestore;

  SaleRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Reference to the sales collection.
  CollectionReference<Map<String, dynamic>> get _salesRef =>
      _firestore.collection(FirestoreCollections.sales);

  /// Reference to the settings collection (for counters).
  CollectionReference<Map<String, dynamic>> get _settingsRef =>
      _firestore.collection(FirestoreCollections.settings);

  // ==================== CREATE ====================

  @override
  Future<SaleEntity> createSale(SaleEntity sale) async {
    try {
      // Use a transaction to ensure atomic creation of sale + items
      return await _firestore.runTransaction<SaleEntity>((transaction) async {
        // Generate sale number if not provided
        String saleNumber = sale.saleNumber;
        if (saleNumber.isEmpty) {
          saleNumber = await _generateSaleNumberInTransaction(
            transaction,
            sale.createdAt,
          );
        }

        // Create the sale document reference
        final saleDocRef = _salesRef.doc();

        // Prepare sale model
        final saleModel = SaleModel.fromEntity(sale.copyWith(
          id: saleDocRef.id,
          saleNumber: saleNumber,
        ));

        // Set the sale document
        transaction.set(saleDocRef, saleModel.toCreateMap());

        // Create items in subcollection
        final itemsRef = saleDocRef.collection(FirestoreCollections.saleItems);
        for (final item in saleModel.items) {
          final itemDocRef = itemsRef.doc();
          final itemWithId = item.copyWith(id: itemDocRef.id);
          transaction.set(itemDocRef, itemWithId.toMap());
        }

        // Return the created sale entity
        return sale.copyWith(
          id: saleDocRef.id,
          saleNumber: saleNumber,
        );
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create sale: ${e.message}',
        code: e.code,
        originalError: e,
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to create sale: $e',
        originalError: e,
      );
    }
  }

  // ==================== READ ====================

  @override
  Future<SaleEntity?> getSaleById(String saleId) async {
    try {
      final doc = await _salesRef.doc(saleId).get();

      if (!doc.exists) return null;

      // Load items from subcollection
      final items = await getSaleItems(saleId);
      final itemModels = items.map((e) => SaleItemModel.fromEntity(e)).toList();

      final saleModel = SaleModel.fromFirestore(doc, items: itemModels);
      return saleModel.toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get sale: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<SaleEntity?> getSaleBySaleNumber(String saleNumber) async {
    try {
      final snapshot = await _salesRef
          .where('saleNumber', isEqualTo: saleNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final items = await getSaleItems(doc.id);
      final itemModels = items.map((e) => SaleItemModel.fromEntity(e)).toList();

      final saleModel = SaleModel.fromFirestore(doc, items: itemModels);
      return saleModel.toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get sale by number: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<SaleEntity>> getSalesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    SaleStatus? status,
    String? cashierId,
    int limit = 100,
  }) async {
    try {
      // Normalize dates to start/end of day
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      Query<Map<String, dynamic>> query = _salesRef
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));

      if (status != null) {
        query = query.where('status', isEqualTo: status.value);
      }

      if (cashierId != null) {
        query = query.where('cashierId', isEqualTo: cashierId);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      final snapshot = await query.get();

      return await _loadSalesWithItems(snapshot.docs);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get sales by date range: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<SaleEntity>> getSalesForDay({
    required DateTime date,
    SaleStatus? status,
    String? cashierId,
  }) async {
    return getSalesByDateRange(
      startDate: date,
      endDate: date,
      status: status,
      cashierId: cashierId,
    );
  }

  @override
  Future<List<SaleEntity>> getTodaysSales({
    SaleStatus? status,
    String? cashierId,
  }) async {
    final today = DateTime.now();
    return getSalesForDay(
      date: today,
      status: status,
      cashierId: cashierId,
    );
  }

  @override
  Future<List<SaleEntity>> getRecentSales({
    int limit = 20,
    String? startAfterSaleId,
    SaleStatus? status,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _salesRef.orderBy('createdAt', descending: true);

      if (status != null) {
        query = query.where('status', isEqualTo: status.value);
      }

      if (startAfterSaleId != null) {
        final startAfterDoc = await _salesRef.doc(startAfterSaleId).get();
        if (startAfterDoc.exists) {
          query = query.startAfterDocument(startAfterDoc);
        }
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return await _loadSalesWithItems(snapshot.docs);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get recent sales: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Stream<List<SaleEntity>> watchSalesForDay({
    required DateTime date,
    SaleStatus? status,
  }) {
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59);

    Query<Map<String, dynamic>> query = _salesRef
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));

    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }

    query = query.orderBy('createdAt', descending: true);

    return query.snapshots().asyncMap((snapshot) async {
      return await _loadSalesWithItems(snapshot.docs);
    });
  }

  @override
  Stream<List<SaleEntity>> watchTodaysSales({SaleStatus? status}) {
    return watchSalesForDay(date: DateTime.now(), status: status);
  }

  // ==================== UPDATE ====================

  @override
  Future<SaleEntity> voidSale({
    required String saleId,
    required String voidedBy,
    required String voidedByName,
    required String reason,
  }) async {
    try {
      final saleRef = _salesRef.doc(saleId);

      await saleRef.update(
        SaleModel.empty().toVoidMap(
          voidedById: voidedBy,
          voidedByUserName: voidedByName,
          reason: reason,
        ),
      );

      // Return updated sale
      final updated = await getSaleById(saleId);
      if (updated == null) {
        throw const DatabaseException(message: 'Sale not found after void');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw VoidSaleException(
        message: 'Failed to void sale: ${e.message}',
        originalError: e,
      );
    }
  }

  @override
  Future<SaleEntity> updateSaleNotes({
    required String saleId,
    required String notes,
  }) async {
    try {
      await _salesRef.doc(saleId).update({
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final updated = await getSaleById(saleId);
      if (updated == null) {
        throw const DatabaseException(message: 'Sale not found after update');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update sale notes: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== SALE NUMBER GENERATION ====================

  @override
  Future<String> generateSaleNumber(DateTime date) async {
    return await _firestore.runTransaction<String>((transaction) async {
      return await _generateSaleNumberInTransaction(transaction, date);
    });
  }

  /// Generates sale number within a transaction.
  Future<String> _generateSaleNumberInTransaction(
    Transaction transaction,
    DateTime date,
  ) async {
    final dateKey = _getDateKey(date);
    final counterDocRef = _settingsRef.doc('sale_counters');

    final counterDoc = await transaction.get(counterDocRef);

    int currentSequence = 0;
    Map<String, dynamic> counters = {};

    if (counterDoc.exists) {
      counters = Map<String, dynamic>.from(counterDoc.data() ?? {});
      currentSequence = (counters[dateKey] as int?) ?? 0;
    }

    // Increment sequence
    final newSequence = currentSequence + 1;
    counters[dateKey] = newSequence;

    // Update counter document
    transaction.set(counterDocRef, counters, SetOptions(merge: true));

    return SaleModel.generateSaleNumber(date, newSequence);
  }

  @override
  Future<int> getSaleSequenceForDate(DateTime date) async {
    try {
      final dateKey = _getDateKey(date);
      final counterDoc = await _settingsRef.doc('sale_counters').get();

      if (!counterDoc.exists) return 0;

      final counters = counterDoc.data() ?? {};
      return (counters[dateKey] as int?) ?? 0;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get sale sequence: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== REPORTING QUERIES ====================

  @override
  Future<double> getTotalSalesAmount({
    required DateTime startDate,
    required DateTime endDate,
    bool excludeVoided = true,
  }) async {
    final sales = await getSalesByDateRange(
      startDate: startDate,
      endDate: endDate,
      status: excludeVoided ? SaleStatus.completed : null,
      limit: 10000, // Large limit for aggregation
    );

    return sales.fold<double>(0.0, (sum, sale) => sum + sale.grandTotal);
  }

  @override
  Future<int> getTotalSalesCount({
    required DateTime startDate,
    required DateTime endDate,
    bool excludeVoided = true,
  }) async {
    try {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      Query<Map<String, dynamic>> query = _salesRef
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));

      if (excludeVoided) {
        query = query.where('status', isEqualTo: SaleStatus.completed.value);
      }

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get sales count: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<Map<PaymentMethod, double>> getSalesByPaymentMethod({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final sales = await getSalesByDateRange(
      startDate: startDate,
      endDate: endDate,
      status: SaleStatus.completed,
      limit: 10000,
    );

    final result = <PaymentMethod, double>{};
    for (final method in PaymentMethod.values) {
      result[method] = 0;
    }

    for (final sale in sales) {
      result[sale.paymentMethod] =
          (result[sale.paymentMethod] ?? 0) + sale.grandTotal;
    }

    return result;
  }

  @override
  Future<SalesSummary> getSalesSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final allSales = await getSalesByDateRange(
      startDate: startDate,
      endDate: endDate,
      limit: 10000,
    );

    final completedSales =
        allSales.where((s) => s.status == SaleStatus.completed).toList();
    final voidedSales =
        allSales.where((s) => s.status == SaleStatus.voided).toList();

    double grossAmount = 0;
    double totalDiscounts = 0;
    double netAmount = 0;
    double totalCost = 0;
    final byPaymentMethod = <PaymentMethod, double>{};

    for (final method in PaymentMethod.values) {
      byPaymentMethod[method] = 0;
    }

    for (final sale in completedSales) {
      grossAmount += sale.subtotal;
      totalDiscounts += sale.totalDiscount;
      netAmount += sale.grandTotal;
      totalCost += sale.totalCost;
      byPaymentMethod[sale.paymentMethod] =
          (byPaymentMethod[sale.paymentMethod] ?? 0) + sale.grandTotal;
    }

    return SalesSummary(
      totalSalesCount: completedSales.length,
      voidedSalesCount: voidedSales.length,
      grossAmount: grossAmount,
      totalDiscounts: totalDiscounts,
      netAmount: netAmount,
      totalCost: totalCost,
      totalProfit: netAmount - totalCost,
      byPaymentMethod: byPaymentMethod,
    );
  }

  // ==================== ITEM QUERIES ====================

  @override
  Future<List<SaleItemEntity>> getSaleItems(String saleId) async {
    try {
      final itemsSnapshot = await _salesRef
          .doc(saleId)
          .collection(FirestoreCollections.saleItems)
          .get();

      return itemsSnapshot.docs
          .map((doc) => SaleItemModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get sale items: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<ProductSalesData>> getTopSellingProducts({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 10,
  }) async {
    final sales = await getSalesByDateRange(
      startDate: startDate,
      endDate: endDate,
      status: SaleStatus.completed,
      limit: 10000,
    );

    // Aggregate by product
    final productAggregates = <String, _ProductAggregate>{};

    for (final sale in sales) {
      for (final item in sale.items) {
        final aggregate = productAggregates.putIfAbsent(
          item.productId,
          () => _ProductAggregate(
            productId: item.productId,
            sku: item.sku,
            name: item.name,
          ),
        );

        aggregate.quantitySold += item.quantity;
        aggregate.totalRevenue +=
            item.calculateNetAmount(isPercentage: sale.isPercentageDiscount);
        aggregate.totalCost += item.totalCost;
      }
    }

    // Sort by quantity and take top N
    final sortedProducts = productAggregates.values.toList()
      ..sort((a, b) => b.quantitySold.compareTo(a.quantitySold));

    return sortedProducts.take(limit).map((agg) {
      return ProductSalesData(
        productId: agg.productId,
        sku: agg.sku,
        name: agg.name,
        quantitySold: agg.quantitySold,
        totalRevenue: agg.totalRevenue,
        totalCost: agg.totalCost,
      );
    }).toList();
  }

  // ==================== HELPER METHODS ====================

  /// Loads sales documents with their items.
  Future<List<SaleEntity>> _loadSalesWithItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final sales = <SaleEntity>[];

    for (final doc in docs) {
      final items = await getSaleItems(doc.id);
      final itemModels = items.map((e) => SaleItemModel.fromEntity(e)).toList();
      final saleModel = SaleModel.fromFirestore(doc, items: itemModels);
      sales.add(saleModel.toEntity());
    }

    return sales;
  }

  /// Gets date key for counter document (YYYYMMDD format).
  String _getDateKey(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }
}

/// Helper class for aggregating product sales data.
class _ProductAggregate {
  final String productId;
  final String sku;
  final String name;
  int quantitySold = 0;
  double totalRevenue = 0;
  double totalCost = 0;

  _ProductAggregate({
    required this.productId,
    required this.sku,
    required this.name,
  });
}
