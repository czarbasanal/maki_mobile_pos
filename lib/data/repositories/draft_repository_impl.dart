import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

/// Firestore implementation of [DraftRepository].
///
/// Data structure:
/// - drafts/{draftId} - Draft document with items stored inline (not subcollection)
///
/// Items are stored inline because:
/// - Drafts are temporary and frequently updated
/// - Simpler to load/update entire draft at once
/// - No need for complex item queries
class DraftRepositoryImpl implements DraftRepository {
  final FirebaseFirestore _firestore;

  DraftRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Reference to the drafts collection.
  CollectionReference<Map<String, dynamic>> get _draftsRef =>
      _firestore.collection(FirestoreCollections.drafts);

  // ==================== CREATE ====================

  @override
  Future<DraftEntity> createDraft(DraftEntity draft) async {
    try {
      final draftModel = DraftModel.fromEntity(draft);
      final docRef = await _draftsRef.add(draftModel.toCreateMap());

      // Return with generated ID
      return draft.copyWith(id: docRef.id);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create draft: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== READ ====================

  @override
  Future<DraftEntity?> getDraftById(String draftId) async {
    try {
      final doc = await _draftsRef.doc(draftId).get();

      if (!doc.exists) return null;

      return DraftModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get draft: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<DraftEntity>> getActiveDrafts({
    String? createdBy,
    int limit = 50,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _draftsRef.where('isConverted', isEqualTo: false);

      if (createdBy != null) {
        query = query.where('createdBy', isEqualTo: createdBy);
      }

      query = query.orderBy('updatedAt', descending: true).limit(limit);

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => DraftModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get active drafts: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<DraftEntity>> getAllDrafts({
    String? createdBy,
    bool includeConverted = false,
    int limit = 100,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _draftsRef;

      if (!includeConverted) {
        query = query.where('isConverted', isEqualTo: false);
      }

      if (createdBy != null) {
        query = query.where('createdBy', isEqualTo: createdBy);
      }

      query = query.orderBy('updatedAt', descending: true).limit(limit);

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => DraftModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get all drafts: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<DraftEntity>> getDraftsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    bool includeConverted = false,
  }) async {
    try {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      Query<Map<String, dynamic>> query = _draftsRef
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));

      if (!includeConverted) {
        query = query.where('isConverted', isEqualTo: false);
      }

      query = query.orderBy('createdAt', descending: true);

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => DraftModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get drafts by date range: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<DraftEntity>> searchDraftsByName({
    required String query,
    bool includeConverted = false,
  }) async {
    try {
      // Firestore doesn't support full-text search, so we do a prefix match
      // For better search, consider Algolia or similar
      final lowercaseQuery = query.toLowerCase();

      // Get all drafts and filter in memory
      // This is not ideal for large datasets but works for typical draft counts
      final allDrafts = await getAllDrafts(
        includeConverted: includeConverted,
        limit: 500,
      );

      return allDrafts
          .where((draft) => draft.name.toLowerCase().contains(lowercaseQuery))
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to search drafts: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Stream<List<DraftEntity>> watchActiveDrafts({String? createdBy}) {
    Query<Map<String, dynamic>> query =
        _draftsRef.where('isConverted', isEqualTo: false);

    if (createdBy != null) {
      query = query.where('createdBy', isEqualTo: createdBy);
    }

    query = query.orderBy('updatedAt', descending: true);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => DraftModel.fromFirestore(doc).toEntity())
          .toList();
    });
  }

  @override
  Stream<DraftEntity?> watchDraft(String draftId) {
    return _draftsRef.doc(draftId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DraftModel.fromFirestore(doc).toEntity();
    });
  }

  // ==================== UPDATE ====================

  @override
  Future<DraftEntity> updateDraft({
    required DraftEntity draft,
    required String updatedBy,
  }) async {
    try {
      final draftModel = DraftModel.fromEntity(draft);
      await _draftsRef.doc(draft.id).update(draftModel.toUpdateMap(updatedBy));

      final updated = await getDraftById(draft.id);
      if (updated == null) {
        throw const DatabaseException(message: 'Draft not found after update');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update draft: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<DraftEntity> updateDraftItems({
    required String draftId,
    required List<SaleItemEntity> items,
    required String updatedBy,
  }) async {
    try {
      final itemModels =
          items.map((item) => SaleItemModel.fromEntity(item)).toList();

      await _draftsRef.doc(draftId).update({
        'items': itemModels.map((item) => item.toMap(includeId: true)).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });

      final updated = await getDraftById(draftId);
      if (updated == null) {
        throw const DatabaseException(message: 'Draft not found after update');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update draft items: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<DraftEntity> updateDraftName({
    required String draftId,
    required String name,
    required String updatedBy,
  }) async {
    try {
      await _draftsRef.doc(draftId).update({
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });

      final updated = await getDraftById(draftId);
      if (updated == null) {
        throw const DatabaseException(message: 'Draft not found after update');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update draft name: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<DraftEntity> updateDraftNotes({
    required String draftId,
    required String? notes,
    required String updatedBy,
  }) async {
    try {
      await _draftsRef.doc(draftId).update({
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });

      final updated = await getDraftById(draftId);
      if (updated == null) {
        throw const DatabaseException(message: 'Draft not found after update');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update draft notes: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<DraftEntity> markDraftAsConverted({
    required String draftId,
    required String saleId,
  }) async {
    try {
      await _draftsRef.doc(draftId).update(
            DraftModel.empty().toConvertedMap(saleId),
          );

      final updated = await getDraftById(draftId);
      if (updated == null) {
        throw const DatabaseException(
            message: 'Draft not found after conversion');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to mark draft as converted: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== DELETE ====================

  @override
  Future<void> deleteDraft(String draftId) async {
    try {
      await _draftsRef.doc(draftId).delete();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to delete draft: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<int> deleteOldConvertedDrafts(DateTime olderThan) async {
    try {
      final snapshot = await _draftsRef
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
        message: 'Failed to delete old converted drafts: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== UTILITY ====================

  @override
  Future<bool> draftNameExists({
    required String name,
    String? excludeDraftId,
  }) async {
    try {
      final snapshot = await _draftsRef
          .where('name', isEqualTo: name)
          .where('isConverted', isEqualTo: false)
          .limit(2) // We need to check if there's another besides excluded
          .get();

      if (excludeDraftId == null) {
        return snapshot.docs.isNotEmpty;
      }

      // Check if any returned draft is not the excluded one
      return snapshot.docs.any((doc) => doc.id != excludeDraftId);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to check draft name: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<int> getActiveDraftCount({String? createdBy}) async {
    try {
      Query<Map<String, dynamic>> query =
          _draftsRef.where('isConverted', isEqualTo: false);

      if (createdBy != null) {
        query = query.where('createdBy', isEqualTo: createdBy);
      }

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get active draft count: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<int> getTotalDraftCount({bool includeConverted = false}) async {
    try {
      Query<Map<String, dynamic>> query = _draftsRef;

      if (!includeConverted) {
        query = query.where('isConverted', isEqualTo: false);
      }

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get total draft count: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
}
