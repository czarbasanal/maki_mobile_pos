import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

/// Firestore implementation of [JobOrderRepository].
///
/// Data structure:
/// - job orders/{jobOrderId} - Job Order document with items stored inline (not subcollection)
///
/// Items are stored inline because:
/// - Job Orders are temporary and frequently updated
/// - Simpler to load/update entire job order at once
/// - No need for complex item queries
class JobOrderRepositoryImpl implements JobOrderRepository {
  final FirebaseFirestore _firestore;

  JobOrderRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Reference to the job orders collection.
  CollectionReference<Map<String, dynamic>> get _jobOrdersRef =>
      _firestore.collection(FirestoreCollections.jobOrders);

  // ==================== CREATE ====================

  @override
  Future<JobOrderEntity> createJobOrder(JobOrderEntity jobOrder) async {
    try {
      final jobOrderModel = JobOrderModel.fromEntity(jobOrder);
      final docRef = await _jobOrdersRef.add(jobOrderModel.toCreateMap());

      // Return with generated ID
      return jobOrder.copyWith(id: docRef.id);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create job order: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== READ ====================

  @override
  Future<JobOrderEntity?> getJobOrderById(String jobOrderId) async {
    try {
      final doc = await _jobOrdersRef.doc(jobOrderId).get();

      if (!doc.exists) return null;

      return JobOrderModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get job order: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<JobOrderEntity>> getActiveJobOrders({
    String? createdBy,
    int limit = 50,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _jobOrdersRef.where('isConverted', isEqualTo: false);

      if (createdBy != null) {
        query = query.where('createdBy', isEqualTo: createdBy);
      }

      query = query.orderBy('updatedAt', descending: true).limit(limit);

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => JobOrderModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get active job orders: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<JobOrderEntity>> getAllJobOrders({
    String? createdBy,
    bool includeConverted = false,
    int limit = 100,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _jobOrdersRef;

      if (!includeConverted) {
        query = query.where('isConverted', isEqualTo: false);
      }

      if (createdBy != null) {
        query = query.where('createdBy', isEqualTo: createdBy);
      }

      query = query.orderBy('updatedAt', descending: true).limit(limit);

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => JobOrderModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get all job orders: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<JobOrderEntity>> getJobOrdersByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    bool includeConverted = false,
  }) async {
    try {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      Query<Map<String, dynamic>> query = _jobOrdersRef
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));

      if (!includeConverted) {
        query = query.where('isConverted', isEqualTo: false);
      }

      query = query.orderBy('createdAt', descending: true);

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => JobOrderModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get job orders by date range: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<JobOrderEntity>> searchJobOrdersByName({
    required String query,
    bool includeConverted = false,
  }) async {
    try {
      // Firestore doesn't support full-text search, so we do a prefix match
      // For better search, consider Algolia or similar
      final lowercaseQuery = query.toLowerCase();

      // Get all job orders and filter in memory
      // This is not ideal for large datasets but works for typical job order counts
      final allJobOrders = await getAllJobOrders(
        includeConverted: includeConverted,
        limit: 500,
      );

      return allJobOrders
          .where((jobOrder) =>
              jobOrder.name.toLowerCase().contains(lowercaseQuery))
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to search job orders: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Stream<List<JobOrderEntity>> watchActiveJobOrders({String? createdBy}) {
    Query<Map<String, dynamic>> query =
        _jobOrdersRef.where('isConverted', isEqualTo: false);

    if (createdBy != null) {
      query = query.where('createdBy', isEqualTo: createdBy);
    }

    query = query.orderBy('updatedAt', descending: true);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => JobOrderModel.fromFirestore(doc).toEntity())
          .toList();
    });
  }

  @override
  Stream<JobOrderEntity?> watchJobOrder(String jobOrderId) {
    return _jobOrdersRef.doc(jobOrderId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return JobOrderModel.fromFirestore(doc).toEntity();
    });
  }

  // ==================== UPDATE ====================

  @override
  Future<JobOrderEntity> updateJobOrder({
    required JobOrderEntity jobOrder,
    required String updatedBy,
  }) async {
    try {
      final jobOrderModel = JobOrderModel.fromEntity(jobOrder);
      await _jobOrdersRef
          .doc(jobOrder.id)
          .update(jobOrderModel.toUpdateMap(updatedBy));

      final updated = await getJobOrderById(jobOrder.id);
      if (updated == null) {
        throw const DatabaseException(
            message: 'Job Order not found after update');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update job order: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<JobOrderEntity> updateJobOrderItems({
    required String jobOrderId,
    required List<SaleItemEntity> items,
    required String updatedBy,
  }) async {
    try {
      final itemModels =
          items.map((item) => SaleItemModel.fromEntity(item)).toList();

      await _jobOrdersRef.doc(jobOrderId).update({
        'items': itemModels.map((item) => item.toMap(includeId: true)).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });

      final updated = await getJobOrderById(jobOrderId);
      if (updated == null) {
        throw const DatabaseException(
            message: 'Job Order not found after update');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update job order items: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<JobOrderEntity> updateJobOrderName({
    required String jobOrderId,
    required String name,
    required String updatedBy,
  }) async {
    try {
      await _jobOrdersRef.doc(jobOrderId).update({
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });

      final updated = await getJobOrderById(jobOrderId);
      if (updated == null) {
        throw const DatabaseException(
            message: 'Job Order not found after update');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update job order name: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<JobOrderEntity> updateJobOrderNotes({
    required String jobOrderId,
    required String? notes,
    required String updatedBy,
  }) async {
    try {
      await _jobOrdersRef.doc(jobOrderId).update({
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });

      final updated = await getJobOrderById(jobOrderId);
      if (updated == null) {
        throw const DatabaseException(
            message: 'Job Order not found after update');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update job order notes: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<JobOrderEntity> markJobOrderAsConverted({
    required String jobOrderId,
    required String saleId,
  }) async {
    try {
      // Idempotent: a replayed checkout re-reconciles its job order, but the
      // rules freeze a converted ticket — skip the write instead of tripping
      // permission-denied on the second pass.
      final current = await getJobOrderById(jobOrderId);
      if (current != null && current.isConverted) {
        return current;
      }

      await _jobOrdersRef.doc(jobOrderId).update(
            JobOrderModel.empty().toConvertedMap(saleId),
          );

      final updated = await getJobOrderById(jobOrderId);
      if (updated == null) {
        throw const DatabaseException(
            message: 'Job Order not found after conversion');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to mark job order as converted: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== DELETE ====================

  @override
  Future<void> deleteJobOrder(String jobOrderId) async {
    try {
      await _jobOrdersRef.doc(jobOrderId).delete();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to delete job order: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<int> deleteOldConvertedJobOrders(DateTime olderThan) async {
    try {
      final snapshot = await _jobOrdersRef
          .where('isConverted', isEqualTo: true)
          .where('convertedAt', isLessThan: Timestamp.fromDate(olderThan))
          .get();

      // Delete in batches
      final batch = _firestore.batch();
      int count = 0;

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
        count++;

        // Firestore batch limit is 500
        if (count % 500 == 0) {
          await batch.commit();
        }
      }

      // Commit remaining
      if (count % 500 != 0) {
        await batch.commit();
      }

      return count;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to delete old converted job orders: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
}
