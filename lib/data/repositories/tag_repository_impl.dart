import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/tag_repository.dart';

/// Firestore implementation of [TagRepository], bound to the single
/// `product_tags` collection.
class TagRepositoryImpl implements TagRepository {
  final FirebaseFirestore _firestore;

  TagRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection(FirestoreCollections.productTags);

  @override
  Stream<List<TagEntity>> watchActive() {
    return _ref
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(_snapshotToSorted);
  }

  @override
  Stream<List<TagEntity>> watchAll() {
    return _ref.snapshots().map(_snapshotToSorted);
  }

  @override
  Future<TagEntity?> getTagById(String tagId) async {
    try {
      final doc = await _ref.doc(tagId).get();
      if (!doc.exists) return null;
      return TagModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get tag: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<TagEntity> createTag({
    required TagEntity tag,
    required String createdBy,
  }) async {
    try {
      if (await nameExists(name: tag.name)) {
        throw DuplicateEntryException(
          field: 'name',
          value: tag.name,
          message: 'A tag with this name already exists',
        );
      }

      final model = TagModel.fromEntity(tag);
      final docRef = await _ref.add(model.toCreateMap(createdBy));
      return tag.copyWith(id: docRef.id, createdBy: createdBy);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create tag: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<TagEntity> updateTag({
    required TagEntity tag,
    required String updatedBy,
  }) async {
    try {
      if (await nameExists(
        name: tag.name,
        excludeTagId: tag.id,
      )) {
        throw DuplicateEntryException(
          field: 'name',
          value: tag.name,
          message: 'A tag with this name already exists',
        );
      }

      final model = TagModel.fromEntity(tag);
      await _ref.doc(tag.id).update(model.toUpdateMap(updatedBy));

      final updated = await getTagById(tag.id);
      if (updated == null) {
        throw const DatabaseException(
          message: 'Tag not found after update',
        );
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update tag: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> setActive({
    required String tagId,
    required bool active,
    required String updatedBy,
  }) async {
    try {
      await _ref.doc(tagId).update({
        'isActive': active,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to ${active ? 'activate' : 'deactivate'} tag: '
            '${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteTag(String tagId) async {
    try {
      await _ref.doc(tagId).delete();
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
    String? excludeTagId,
  }) async {
    try {
      final snapshot =
          await _ref.where('name', isEqualTo: name).limit(2).get();
      if (excludeTagId == null) {
        return snapshot.docs.isNotEmpty;
      }
      return snapshot.docs.any((doc) => doc.id != excludeTagId);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to check tag name: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // Sort client-side A→Z (case-insensitive). Avoids a Firestore index and the
  // dataset is small.
  List<TagEntity> _snapshotToSorted(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final list = snapshot.docs
        .map((doc) => TagModel.fromFirestore(doc).toEntity())
        .toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }
}
