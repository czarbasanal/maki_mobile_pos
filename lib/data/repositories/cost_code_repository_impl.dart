import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/cost_code_repository.dart';

/// Firestore implementation of [CostCodeRepository].
class CostCodeRepositoryImpl implements CostCodeRepository {
  final FirebaseFirestore _firestore;
  static const String _documentId = 'cost_code_mapping';

  CostCodeRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _mappingRef =>
      _firestore.collection(FirestoreCollections.settings).doc(_documentId);

  @override
  Future<CostCodeEntity> getCostCodeMapping() async {
    try {
      final doc = await _mappingRef.get();

      if (!doc.exists || doc.data() == null) {
        // Return default mapping if none exists
        return CostCodeEntity.defaultMapping();
      }

      return CostCodeModel.fromMap(doc.data()!).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get cost code mapping: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Stream<CostCodeEntity> watchCostCodeMapping() {
    return _mappingRef.snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return CostCodeEntity.defaultMapping();
      }
      return CostCodeModel.fromMap(doc.data()!).toEntity();
    });
  }

  @override
  Future<void> updateCostCodeMapping(CostCodeEntity mapping) async {
    try {
      final model = CostCodeModel.fromEntity(mapping);
      await _mappingRef.set(model.toMap(forUpdate: true));
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update cost code mapping: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> resetToDefaultMapping() async {
    final defaultMapping = CostCodeEntity.defaultMapping();
    await updateCostCodeMapping(defaultMapping);
  }
}
