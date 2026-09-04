import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/adjustment_reason_repository.dart';

/// Seed data for default adjustment reasons. Each tuple is (name, requiresNote).
/// Used by [AdjustmentReasonRepositoryImpl.seedDefaults] on first initialization.
const kSeedAdjustmentReasons = [
  _AdjustmentReasonSeed('Delivery', false),
  _AdjustmentReasonSeed('Count correction', true),
  _AdjustmentReasonSeed('Damaged', true),
  _AdjustmentReasonSeed('Lost', true),
  _AdjustmentReasonSeed('Returned', false),
  _AdjustmentReasonSeed('Transfer', false),
];

/// Private helper class for seed data serialization.
class _AdjustmentReasonSeed {
  final String name;
  final bool requiresNote;

  const _AdjustmentReasonSeed(this.name, this.requiresNote);
}

/// Firestore implementation of [AdjustmentReasonRepository], bound to the single
/// `adjustment_reasons` collection.
class AdjustmentReasonRepositoryImpl implements AdjustmentReasonRepository {
  final FirebaseFirestore _firestore;

  AdjustmentReasonRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection(FirestoreCollections.adjustmentReasons);

  @override
  Stream<List<AdjustmentReasonEntity>> watchActive() {
    return _ref
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(_snapshotToSorted);
  }

  @override
  Stream<List<AdjustmentReasonEntity>> watchAll() {
    return _ref.snapshots().map(_snapshotToSorted);
  }

  @override
  Future<AdjustmentReasonEntity?> getReasonById(String reasonId) async {
    try {
      final doc = await _ref.doc(reasonId).get();
      if (!doc.exists) return null;
      return AdjustmentReasonModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get adjustment reason: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<AdjustmentReasonEntity> createAdjustmentReason({
    required AdjustmentReasonEntity reason,
    required String createdBy,
  }) async {
    try {
      if (await nameExists(name: reason.name)) {
        throw DuplicateEntryException(
          field: 'name',
          value: reason.name,
          message: 'An adjustment reason with this name already exists',
        );
      }

      final model = AdjustmentReasonModel.fromEntity(reason);
      final docRef = await _ref.add(model.toCreateMap(createdBy));
      return reason.copyWith(id: docRef.id, createdBy: createdBy);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create adjustment reason: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<AdjustmentReasonEntity> updateAdjustmentReason({
    required AdjustmentReasonEntity reason,
    required String updatedBy,
  }) async {
    try {
      if (await nameExists(
        name: reason.name,
        excludeReasonId: reason.id,
      )) {
        throw DuplicateEntryException(
          field: 'name',
          value: reason.name,
          message: 'An adjustment reason with this name already exists',
        );
      }

      final model = AdjustmentReasonModel.fromEntity(reason);
      await _ref.doc(reason.id).update(model.toUpdateMap(updatedBy));

      final updated = await getReasonById(reason.id);
      if (updated == null) {
        throw const DatabaseException(
          message: 'Adjustment reason not found after update',
        );
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update adjustment reason: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> setActive({
    required String reasonId,
    required bool active,
    required String updatedBy,
  }) async {
    try {
      await _ref.doc(reasonId).update({
        'isActive': active,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to ${active ? 'activate' : 'deactivate'} adjustment reason: '
            '${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteReason(String reasonId) async {
    try {
      await _ref.doc(reasonId).delete();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to delete: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<bool> nameExists({
    required String name,
    String? excludeReasonId,
  }) async {
    try {
      final snapshot =
          await _ref.where('name', isEqualTo: name).limit(2).get();
      if (excludeReasonId == null) {
        return snapshot.docs.isNotEmpty;
      }
      return snapshot.docs.any((doc) => doc.id != excludeReasonId);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to check adjustment reason name: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> seedDefaults(String createdBy) async {
    try {
      final batch = _firestore.batch();
      for (final seed in kSeedAdjustmentReasons) {
        final docRef = _ref.doc();
        final model = AdjustmentReasonModel(
          id: docRef.id,
          name: seed.name,
          requiresNote: seed.requiresNote,
          isActive: true,
          createdAt: DateTime.now(),
          createdBy: createdBy,
        );
        batch.set(docRef, model.toCreateMap(createdBy));
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to seed adjustment reasons: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // Sort client-side A→Z (case-insensitive). Avoids a Firestore index and the
  // dataset is small.
  List<AdjustmentReasonEntity> _snapshotToSorted(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final list = snapshot.docs
        .map((doc) => AdjustmentReasonModel.fromFirestore(doc).toEntity())
        .toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }
}
