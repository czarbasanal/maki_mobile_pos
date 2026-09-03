import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository contract for admin-managed Tag operations.
///
/// Backed by the single `product_tags` collection.
abstract class TagRepository {
  /// Streams active tags ordered A→Z by name.
  Stream<List<TagEntity>> watchActive();

  /// Streams all tags (active + inactive) for admin management.
  Stream<List<TagEntity>> watchAll();

  /// Reads a single tag by ID.
  Future<TagEntity?> getTagById(String tagId);

  /// Creates a tag. Returns the persisted entity with its assigned ID.
  Future<TagEntity> createTag({
    required TagEntity tag,
    required String createdBy,
  });

  /// Updates an existing tag.
  Future<TagEntity> updateTag({
    required TagEntity tag,
    required String updatedBy,
  });

  /// Soft-deletes (deactivates) or reactivates a tag.
  Future<void> setActive({
    required String tagId,
    required bool active,
    required String updatedBy,
  });

  /// Permanently deletes the entry.
  Future<void> deleteTag(String tagId);

  /// Checks whether a tag name already exists (exact match).
  Future<bool> nameExists({
    required String name,
    String? excludeTagId,
  });
}
