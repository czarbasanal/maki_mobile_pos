import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/supplier_repository.dart';

/// Firestore implementation of [SupplierRepository].
class SupplierRepositoryImpl implements SupplierRepository {
  final FirebaseFirestore _firestore;

  SupplierRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _suppliersRef =>
      _firestore.collection(FirestoreCollections.suppliers);

  // ==================== CREATE ====================

  @override
  Future<SupplierEntity> createSupplier({
    required SupplierEntity supplier,
    required String createdBy,
  }) async {
    try {
      // Check for duplicate name
      if (await nameExists(name: supplier.name)) {
        throw DuplicateEntryException(
          field: 'name',
          value: supplier.name,
          message: 'A supplier with this name already exists',
        );
      }

      final model = SupplierModel.fromEntity(supplier);
      final docRef = await _suppliersRef.add(model.toCreateMap(createdBy));

      return supplier.copyWith(id: docRef.id);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create supplier: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== READ ====================

  @override
  Future<SupplierEntity?> getSupplierById(String supplierId) async {
    try {
      final doc = await _suppliersRef.doc(supplierId).get();
      if (!doc.exists) return null;
      return SupplierModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get supplier: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<SupplierEntity>> getSuppliers({int limit = 100}) async {
    return getAllSuppliers(includeInactive: false, limit: limit);
  }

  @override
  Future<List<SupplierEntity>> getAllSuppliers({
    bool includeInactive = false,
    int limit = 100,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _suppliersRef.orderBy('name');

      if (!includeInactive) {
        query = query.where('isActive', isEqualTo: true);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => SupplierModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get suppliers: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<List<SupplierEntity>> searchSuppliers({
    required String query,
    int limit = 20,
  }) async {
    try {
      if (query.isEmpty) return [];

      final queryLower = query.toLowerCase();

      // Use searchKeywords array for efficient searching
      final snapshot = await _suppliersRef
          .where('isActive', isEqualTo: true)
          .where('searchKeywords', arrayContains: queryLower)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => SupplierModel.fromFirestore(doc).toEntity())
          .toList();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to search suppliers: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Stream<List<SupplierEntity>> watchSuppliers() {
    return _suppliersRef
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SupplierModel.fromFirestore(doc).toEntity())
            .toList());
  }

  @override
  Stream<SupplierEntity?> watchSupplier(String supplierId) {
    return _suppliersRef.doc(supplierId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return SupplierModel.fromFirestore(doc).toEntity();
    });
  }

  // ==================== UPDATE ====================

  @override
  Future<SupplierEntity> updateSupplier({
    required SupplierEntity supplier,
    required String updatedBy,
  }) async {
    try {
      // Check for duplicate name (excluding current supplier)
      if (await nameExists(
          name: supplier.name, excludeSupplierId: supplier.id)) {
        throw DuplicateEntryException(
          field: 'name',
          value: supplier.name,
          message: 'A supplier with this name already exists',
        );
      }

      final model = SupplierModel.fromEntity(supplier);
      await _suppliersRef.doc(supplier.id).update(model.toUpdateMap(updatedBy));

      final updated = await getSupplierById(supplier.id);
      if (updated == null) {
        throw const DatabaseException(
            message: 'Supplier not found after update');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update supplier: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> deactivateSupplier({
    required String supplierId,
    required String updatedBy,
  }) async {
    try {
      await _suppliersRef.doc(supplierId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to deactivate supplier: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> reactivateSupplier({
    required String supplierId,
    required String updatedBy,
  }) async {
    try {
      await _suppliersRef.doc(supplierId).update({
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to reactivate supplier: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  /// Updates supplier product count and inventory value.
  Future<void> updateSupplierStats({
    required String supplierId,
    required int productCount,
    required double totalInventoryValue,
  }) async {
    try {
      await _suppliersRef.doc(supplierId).update({
        'productCount': productCount,
        'totalInventoryValue': totalInventoryValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update supplier stats: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // ==================== UTILITY ====================

  @override
  Future<bool> nameExists({
    required String name,
    String? excludeSupplierId,
  }) async {
    try {
      final snapshot =
          await _suppliersRef.where('name', isEqualTo: name).limit(2).get();

      if (excludeSupplierId == null) {
        return snapshot.docs.isNotEmpty;
      }

      return snapshot.docs.any((doc) => doc.id != excludeSupplierId);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to check name existence: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<int> getSupplierCount({bool activeOnly = true}) async {
    try {
      Query<Map<String, dynamic>> query = _suppliersRef;

      if (activeOnly) {
        query = query.where('isActive', isEqualTo: true);
      }

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get supplier count: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
}
