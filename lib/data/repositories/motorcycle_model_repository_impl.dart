import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/motorcycle_model_repository.dart';

/// Firestore implementation of [MotorcycleModelRepository], bound to the
/// `motorcycle_models` collection. Thin (talks to Firestore directly, like
/// [MechanicRepositoryImpl]).
class MotorcycleModelRepositoryImpl implements MotorcycleModelRepository {
  final FirebaseFirestore _firestore;
  MotorcycleModelRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection(FirestoreCollections.motorcycleModels);

  @override
  Stream<List<MotorcycleModelEntity>> watchActive() =>
      _ref.where('isActive', isEqualTo: true).snapshots().map(_sorted);

  @override
  Stream<List<MotorcycleModelEntity>> watchAll() =>
      _ref.snapshots().map(_sorted);

  @override
  Future<MotorcycleModelEntity?> getById(String id) async {
    try {
      final doc = await _ref.doc(id).get();
      if (!doc.exists) return null;
      return MotorcycleModelModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
          message: 'Failed to get motorcycle model: ${e.message}',
          code: e.code,
          originalError: e);
    }
  }

  @override
  Future<MotorcycleModelEntity> create({
    required MotorcycleModelEntity model,
    required String createdBy,
  }) async {
    try {
      final m = MotorcycleModelModel.fromEntity(model);
      final ref = await _ref.add(m.toCreateMap(createdBy));
      return model.copyWith(id: ref.id, createdBy: createdBy);
    } on FirebaseException catch (e) {
      throw DatabaseException(
          message: 'Failed to create motorcycle model: ${e.message}',
          code: e.code,
          originalError: e);
    }
  }

  @override
  Future<MotorcycleModelEntity> update({
    required MotorcycleModelEntity model,
    required String updatedBy,
  }) async {
    try {
      final m = MotorcycleModelModel.fromEntity(model);
      await _ref.doc(model.id).update(m.toUpdateMap(updatedBy));
      final updated = await getById(model.id);
      if (updated == null) {
        throw const DatabaseException(message: 'Model not found after update');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
          message: 'Failed to update motorcycle model: ${e.message}',
          code: e.code,
          originalError: e);
    }
  }

  @override
  Future<void> setActive({
    required String id,
    required bool active,
    required String updatedBy,
  }) async {
    try {
      await _ref.doc(id).update({
        'isActive': active,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
          message: 'Failed to set model active: ${e.message}',
          code: e.code,
          originalError: e);
    }
  }

  @override
  Future<MotorcycleModelEntity?> findByNormalizedKey(
      String normalizedKey) async {
    try {
      final snap = await _ref
          .where('normalizedName', isEqualTo: normalizedKey)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return MotorcycleModelModel.fromFirestore(snap.docs.first).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
          message: 'Failed to look up motorcycle model: ${e.message}',
          code: e.code,
          originalError: e);
    }
  }

  List<MotorcycleModelEntity> _sorted(
          QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs
          .map((d) => MotorcycleModelModel.fromFirestore(d).toEntity())
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}
