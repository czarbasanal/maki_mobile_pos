import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/mechanic_repository.dart';

/// Firestore implementation of [MechanicRepository], bound to the single
/// `mechanics` collection.
class MechanicRepositoryImpl implements MechanicRepository {
  final FirebaseFirestore _firestore;

  MechanicRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection(FirestoreCollections.mechanics);

  @override
  Stream<List<MechanicEntity>> watchActive() {
    return _ref
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(_snapshotToSorted);
  }

  @override
  Stream<List<MechanicEntity>> watchAll() {
    return _ref.snapshots().map(_snapshotToSorted);
  }

  @override
  Future<MechanicEntity?> getMechanicById(String mechanicId) async {
    try {
      final doc = await _ref.doc(mechanicId).get();
      if (!doc.exists) return null;
      return MechanicModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get mechanic: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<MechanicEntity> createMechanic({
    required MechanicEntity mechanic,
    required String createdBy,
  }) async {
    try {
      if (await nameExists(name: mechanic.name)) {
        throw DuplicateEntryException(
          field: 'name',
          value: mechanic.name,
          message: 'A mechanic with this name already exists',
        );
      }

      final model = MechanicModel.fromEntity(mechanic);
      final docRef = await _ref.add(model.toCreateMap(createdBy));
      return mechanic.copyWith(id: docRef.id, createdBy: createdBy);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create mechanic: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<MechanicEntity> updateMechanic({
    required MechanicEntity mechanic,
    required String updatedBy,
  }) async {
    try {
      if (await nameExists(
        name: mechanic.name,
        excludeMechanicId: mechanic.id,
      )) {
        throw DuplicateEntryException(
          field: 'name',
          value: mechanic.name,
          message: 'A mechanic with this name already exists',
        );
      }

      final model = MechanicModel.fromEntity(mechanic);
      await _ref.doc(mechanic.id).update(model.toUpdateMap(updatedBy));

      final updated = await getMechanicById(mechanic.id);
      if (updated == null) {
        throw const DatabaseException(
          message: 'Mechanic not found after update',
        );
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update mechanic: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> setActive({
    required String mechanicId,
    required bool active,
    required String updatedBy,
  }) async {
    try {
      await _ref.doc(mechanicId).update({
        'isActive': active,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to ${active ? 'activate' : 'deactivate'} mechanic: '
            '${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<bool> nameExists({
    required String name,
    String? excludeMechanicId,
  }) async {
    try {
      final snapshot =
          await _ref.where('name', isEqualTo: name).limit(2).get();
      if (excludeMechanicId == null) {
        return snapshot.docs.isNotEmpty;
      }
      return snapshot.docs.any((doc) => doc.id != excludeMechanicId);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to check mechanic name: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // Sort client-side A→Z (case-insensitive). Avoids a Firestore index and the
  // dataset is small.
  List<MechanicEntity> _snapshotToSorted(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final list = snapshot.docs
        .map((doc) => MechanicModel.fromFirestore(doc).toEntity())
        .toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }
}
