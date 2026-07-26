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
  ///
  /// When [assignCode], the create runs inside a transaction that also
  /// claims the next sequential 4-digit Code128 category code (see
  /// `category_codes/_counter` + registry docs) and stamps it onto the
  /// created category. Callers that don't need auto-SKU codes (e.g. expense
  /// categories) leave this false, which keeps the original plain-add path.
  Future<CategoryEntity> createCategory({
    required CategoryEntity category,
    required String createdBy,
    bool assignCode = false,
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

  /// Permanently deletes the entry. Historical records keep the snapshotted
  /// name; prefer setActive(false) to merely hide an entry.
  Future<void> deleteCategory(String categoryId);

  /// Checks whether a category name already exists (case-insensitive match
  /// is left to the repository implementation; current impl uses exact match).
  Future<bool> nameExists({
    required String name,
    String? excludeCategoryId,
  });

  /// Plain (non-claiming) read of a Code128 category-code registry doc's
  /// `nextSequence` — lets a form preview the next candidate SKU without
  /// reserving it. The actual claim happens later, inside the product-create
  /// transaction (see `ProductRepository.createProduct`'s `autoSkuCategoryCode`).
  ///
  /// Throws [DatabaseException] (code `unknown-category-code`) if no registry
  /// doc exists for [categoryCode].
  Future<int> peekNextSequence(String categoryCode);
}
