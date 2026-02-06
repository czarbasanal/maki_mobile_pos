import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/receiving_model.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/receiving_repository.dart';

/// Firestore implementation of [ReceivingRepository].
class ReceivingRepositoryImpl implements ReceivingRepository {
  final FirebaseFirestore _firestore;
  final ProductRepository _productRepository;

  ReceivingRepositoryImpl({
    FirebaseFirestore? firestore,
    required ProductRepository productRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _productRepository = productRepository;

  CollectionReference<Map<String, dynamic>> get _receivingsRef =>
      _firestore.collection(FirestoreCollections.receivings);

  // ==================== CREATE ====================

  @override
  Future<ReceivingEntity> createReceiving(ReceivingEntity receiving) async {
    try {
      final model = ReceivingModel.fromEntity(receiving);
      final docRef = await _receivingsRef.add(model.toMap(forCreate: true));
      return receiving.copyWith(id: docRef.id);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create receiving: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== READ ====================

  @override
  Future<ReceivingEntity?> getReceivingById(String receivingId) async {
    try {
      final doc = await _receivingsRef.doc(receivingId).get();
      if (!doc.exists) return null;
      return ReceivingModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get receiving: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<ReceivingEntity>> getReceivings({
    ReceivingStatus? status,
    String? supplierId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _receivingsRef.orderBy('createdAt', descending: true);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      if (supplierId != null) {
        query = query.where('supplierId', isEqualTo: supplierId);
      }

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: endDate);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ReceivingModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get receivings: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<ReceivingEntity>> getRecentReceivings({int limit = 20}) async {
    return getReceivings(limit: limit);
  }

  @override
  Future<List<ReceivingEntity>> getDraftReceivings() async {
    return getReceivings(status: ReceivingStatus.draft);
  }

  @override
  Stream<List<ReceivingEntity>> watchReceivings({
    ReceivingStatus? status,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query =
        _receivingsRef.orderBy('createdAt', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    query = query.limit(limit);

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => ReceivingModel.fromFirestore(doc).toEntity())
        .toList());
  }

  // ==================== UPDATE ====================

  @override
  Future<ReceivingEntity> updateReceiving(ReceivingEntity receiving) async {
    try {
      final model = ReceivingModel.fromEntity(receiving);
      await _receivingsRef
          .doc(receiving.id)
          .update(model.toMap(forUpdate: true));

      final updated = await getReceivingById(receiving.id);
      if (updated == null) {
        throw const DatabaseException(
            message: 'Receiving not found after update');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update receiving: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<ReceivingEntity> completeReceiving({
    required String receivingId,
    required String completedBy,
  }) async {
    try {
      final receiving = await getReceivingById(receivingId);
      if (receiving == null) {
        throw const DatabaseException(message: 'Receiving not found');
      }

      if (receiving.status != ReceivingStatus.draft) {
        throw const DatabaseException(
            message: 'Only draft receivings can be completed');
      }

      // Process each item
      final processedItems = <ReceivingItemEntity>[];

      for (final item in receiving.items) {
        final processedItem = await _processReceivingItem(item, completedBy);
        processedItems.add(processedItem);
      }

      // Update receiving status
      final completedReceiving = receiving.copyWith(
        items: processedItems,
        status: ReceivingStatus.completed,
        completedAt: DateTime.now(),
        completedBy: completedBy,
      );

      return updateReceiving(completedReceiving);
    } on DatabaseException {
      rethrow;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to complete receiving: $e',
        originalError: e,
      );
    }
  }

  /// Processes a single receiving item.
  ///
  /// Handles:
  /// - Adding stock to existing products
  /// - Creating variations for different costs
  /// - Recording price history
  Future<ReceivingItemEntity> _processReceivingItem(
    ReceivingItemEntity item,
    String updatedBy,
  ) async {
    if (item.productId == null) {
      // New product - would need to create it first
      // For now, return as-is (product creation is separate flow)
      return item;
    }

    // Get existing product
    final product = await _productRepository.getProductById(item.productId!);
    if (product == null) {
      return item;
    }

    // Check if cost is different
    if ((item.unitCost - product.cost).abs() > 0.01) {
      // Cost is different - create a variation
      final variation = await _productRepository.createVariation(
        originalProduct: product,
        newCost: item.unitCost,
        newCostCode: item.costCode,
        createdBy: updatedBy,
      );

      // Update stock on the new variation
      await _productRepository.updateStock(
        productId: variation.id,
        quantityChange: item.quantity,
        updatedBy: updatedBy,
      );

      return item.copyWith(
        isNewVariation: true,
        newProductId: variation.id,
        sku: variation.sku,
      );
    } else {
      // Same cost - just add stock
      await _productRepository.updateStock(
        productId: item.productId!,
        quantityChange: item.quantity,
        updatedBy: updatedBy,
      );

      return item;
    }
  }

  @override
  Future<void> cancelReceiving({
    required String receivingId,
    required String cancelledBy,
    String? reason,
  }) async {
    try {
      final receiving = await getReceivingById(receivingId);
      if (receiving == null) {
        throw const DatabaseException(message: 'Receiving not found');
      }

      if (receiving.status == ReceivingStatus.completed) {
        throw const DatabaseException(
            message: 'Cannot cancel completed receiving');
      }

      await _receivingsRef.doc(receivingId).update({
        'status': ReceivingStatus.cancelled.name,
        'notes': reason != null
            ? '${receiving.notes ?? ''}\nCancelled: $reason'.trim()
            : receiving.notes,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to cancel receiving: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== DELETE ====================

  @override
  Future<void> deleteReceiving(String receivingId) async {
    try {
      final receiving = await getReceivingById(receivingId);
      if (receiving == null) {
        throw const DatabaseException(message: 'Receiving not found');
      }

      if (receiving.status != ReceivingStatus.draft) {
        throw const DatabaseException(
            message: 'Only draft receivings can be deleted');
      }

      await _receivingsRef.doc(receivingId).delete();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to delete receiving: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== UTILITY ====================

  @override
  Future<String> generateReferenceNumber() async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    // Get count for today
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _receivingsRef
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
        .count()
        .get();

    final sequence = (snapshot.count ?? 0) + 1;
    return 'RCV-$dateStr-${sequence.toString().padLeft(3, '0')}';
  }

  @override
  Future<Map<ReceivingStatus, int>> getReceivingCounts() async {
    try {
      final counts = <ReceivingStatus, int>{};

      for (final status in ReceivingStatus.values) {
        final snapshot = await _receivingsRef
            .where('status', isEqualTo: status.name)
            .count()
            .get();
        counts[status] = snapshot.count ?? 0;
      }

      return counts;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get receiving counts: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
}
