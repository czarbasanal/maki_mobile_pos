import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository contract for admin-managed Category operations.
///
/// One contract serves both product and expense categories. Implementations
/// are bound to a specific Firestore collection at construction time.
abstract class CategoryRepository {
  /// Streams active categories ordered by sortOrder, then name.
  Stream<List<CategoryEntity>> watchCategories();

  /// Streams all categories (active + inactive) for admin management.
  Stream<List<CategoryEntity>> watchAllCategories();

  /// Reads a single category by ID.
  Future<CategoryEntity?> getCategoryById(String categoryId);

  /// Creates a category. Returns the persisted entity with its assigned ID.
  Future<CategoryEntity> createCategory({
    required CategoryEntity category,
    required String createdBy,
  });

  /// Updates an existing category.
  Future<CategoryEntity> updateCategory({
    required CategoryEntity category,
    required String updatedBy,
  });

  /// Soft-deletes (deactivates) a category. Existing references survive.
  Future<void> setActive({
    required String categoryId,
    required bool active,
    required String updatedBy,
  });

  /// Checks whether a category name already exists (case-insensitive match
  /// is left to the repository implementation; current impl uses exact match).
  Future<bool> nameExists({
    required String name,
    String? excludeCategoryId,
  });
}
