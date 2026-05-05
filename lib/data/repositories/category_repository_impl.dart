import 'package:cloud_firestore/cloud_firestore.dart';
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
      final docRef = await _ref.add(model.toCreateMap(createdBy));
      return category.copyWith(id: docRef.id, createdBy: createdBy);
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
