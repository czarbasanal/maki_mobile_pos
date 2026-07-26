import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/category_repository.dart';

/// Firestore implementation of [CategoryRepository], bound to the collection
/// passed in at construction time. The same shape is reused for product and
/// expense category collections.
class CategoryRepositoryImpl implements CategoryRepository {
  final FirebaseFirestore _firestore;
  final String _collectionName;

  CategoryRepositoryImpl({
    required String collectionName,
    FirebaseFirestore? firestore,
  })  : _collectionName = collectionName,
        _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection(_collectionName);

  CollectionReference<Map<String, dynamic>> get _categoryCodesRef =>
      _firestore.collection(FirestoreCollections.categoryCodes);

  @override
  Stream<List<CategoryEntity>> watchCategories() {
    return _ref
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(_snapshotToSorted);
  }

  @override
  Stream<List<CategoryEntity>> watchAllCategories() {
    return _ref.snapshots().map(_snapshotToSorted);
  }

  @override
  Future<CategoryEntity?> getCategoryById(String categoryId) async {
    try {
      final doc = await _ref.doc(categoryId).get();
      if (!doc.exists) return null;
      return CategoryModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get category: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<CategoryEntity> createCategory({
    required CategoryEntity category,
    required String createdBy,
    bool assignCode = false,
  }) async {
    try {
      if (await nameExists(name: category.name)) {
        throw DuplicateEntryException(
          field: 'name',
          value: category.name,
          message: 'A category with this name already exists',
        );
      }

      final model = CategoryModel.fromEntity(category);

      if (!assignCode) {
        final docRef = await _ref.add(model.toCreateMap(createdBy));
        return category.copyWith(id: docRef.id, createdBy: createdBy);
      }

      // Claim the next sequential Code128 category code and write the
      // category atomically. Reads precede writes (Firestore transaction
      // rule) — see ProductRepositoryImpl.createProduct for the same idiom.
      final docRef = _ref.doc(); // pre-allocate id for the transaction
      final counterRef = _categoryCodesRef.doc('_counter');
      var assignedCode = '';

      await _firestore.runTransaction((tx) async {
        final counterSnap = await tx.get(counterRef);
        final next = (counterSnap.data()?['next'] as int?) ?? 1;
        assignedCode = next.toString().padLeft(4, '0');
        final registryRef = _categoryCodesRef.doc(assignedCode);

        tx.set(docRef, {
          ...model.toCreateMap(createdBy),
          'code': assignedCode,
        });
        tx.set(registryRef, {
          'categoryId': docRef.id,
          'nameSnapshot': category.name,
          'assignedAt': FieldValue.serverTimestamp(),
          'nextSequence': 1,
        });
        tx.set(counterRef, {'next': next + 1});
      });

      return category.copyWith(
        id: docRef.id,
        createdBy: createdBy,
        code: assignedCode,
      );
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create category: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<CategoryEntity> updateCategory({
    required CategoryEntity category,
    required String updatedBy,
  }) async {
    try {
      if (await nameExists(
        name: category.name,
        excludeCategoryId: category.id,
      )) {
        throw DuplicateEntryException(
          field: 'name',
          value: category.name,
          message: 'A category with this name already exists',
        );
      }

      final model = CategoryModel.fromEntity(category);
      await _ref.doc(category.id).update(model.toUpdateMap(updatedBy));

      final updated = await getCategoryById(category.id);
      if (updated == null) {
        throw const DatabaseException(
          message: 'Category not found after update',
        );
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update category: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> setActive({
    required String categoryId,
    required bool active,
    required String updatedBy,
  }) async {
    try {
      await _ref.doc(categoryId).update({
        'isActive': active,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to ${active ? 'activate' : 'deactivate'} category: '
            '${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    try {
      await _ref.doc(categoryId).delete();
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
    String? excludeCategoryId,
  }) async {
    try {
      final snapshot =
          await _ref.where('name', isEqualTo: name).limit(2).get();
      if (excludeCategoryId == null) {
        return snapshot.docs.isNotEmpty;
      }
      return snapshot.docs.any((doc) => doc.id != excludeCategoryId);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to check category name: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // Sort client-side A→Z (case-insensitive). Avoids needing a Firestore
  // index and the dataset is small.
  List<CategoryEntity> _snapshotToSorted(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final list = snapshot.docs
        .map((doc) => CategoryModel.fromFirestore(doc).toEntity())
        .toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }
}
