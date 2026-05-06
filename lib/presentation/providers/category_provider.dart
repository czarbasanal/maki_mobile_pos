import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/category_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/category_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

/// Distinguishes the admin-managed name-list collections.
///
/// Each kind maps to a separate Firestore collection sharing the same shape
/// — see [CategoryRepositoryImpl], which is parameterised on collection name.
enum CategoryKind {
  product,
  expense,
  unit;

  String get collectionName {
    switch (this) {
      case CategoryKind.product:
        return FirestoreCollections.productCategories;
      case CategoryKind.expense:
        return FirestoreCollections.expenseCategories;
      case CategoryKind.unit:
        return FirestoreCollections.units;
    }
  }

  /// Singular human-readable label for dialog titles and snackbars
  /// (e.g. "New Product Category", "Unit created").
  String get singularLabel {
    switch (this) {
      case CategoryKind.product:
        return 'Product Category';
      case CategoryKind.expense:
        return 'Expense Category';
      case CategoryKind.unit:
        return 'Unit';
    }
  }

  /// Plural human-readable label for list copy and empty states.
  String get pluralLabel {
    switch (this) {
      case CategoryKind.product:
        return 'product categories';
      case CategoryKind.expense:
        return 'expense categories';
      case CategoryKind.unit:
        return 'units';
    }
  }
}

// ==================== REPOSITORY PROVIDER ====================

/// Provides a [CategoryRepository] bound to the requested [CategoryKind].
final categoryRepositoryProvider =
    Provider.family<CategoryRepository, CategoryKind>((ref, kind) {
  return CategoryRepositoryImpl(
    collectionName: kind.collectionName,
    firestore: ref.watch(firestoreProvider),
  );
});

// ==================== CATEGORY QUERIES ====================

/// Streams active categories of the given kind. Auth-gated so it does not
/// emit a permission-denied error before the user's session is warm.
final activeCategoriesProvider =
    StreamProvider.family<List<CategoryEntity>, CategoryKind>((ref, kind) {
  return authGatedStream(ref, (_) {
    return ref.watch(categoryRepositoryProvider(kind)).watchCategories();
  });
});

/// Streams all categories of the given kind, including inactive ones —
/// for the admin management screen.
final allCategoriesProvider =
    StreamProvider.family<List<CategoryEntity>, CategoryKind>((ref, kind) {
  return authGatedStream(ref, (_) {
    return ref.watch(categoryRepositoryProvider(kind)).watchAllCategories();
  });
});

// ==================== CATEGORY OPERATIONS ====================

/// Notifier for category mutations. One notifier instance per [CategoryKind].
/// Permission is checked at the route layer; this notifier does not duplicate
/// that gate.
class CategoryOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final CategoryKind _kind;

  CategoryOperationsNotifier(this._ref, this._kind)
      : super(const AsyncValue.data(null));

  CategoryRepository get _repository =>
      _ref.read(categoryRepositoryProvider(_kind));

  String _requireUserId() {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      throw const UnauthenticatedException();
    }
    return user.id;
  }

  Future<CategoryEntity?> create({required CategoryEntity category}) async {
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      final created = await _repository.createCategory(
        category: category,
        createdBy: actorId,
      );
      state = const AsyncValue.data(null);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<CategoryEntity?> update({required CategoryEntity category}) async {
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      final updated = await _repository.updateCategory(
        category: category,
        updatedBy: actorId,
      );
      state = const AsyncValue.data(null);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deactivate(String categoryId) =>
      _setActive(categoryId: categoryId, active: false);

  Future<bool> reactivate(String categoryId) =>
      _setActive(categoryId: categoryId, active: true);

  Future<bool> _setActive({
    required String categoryId,
    required bool active,
  }) async {
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      await _repository.setActive(
        categoryId: categoryId,
        active: active,
        updatedBy: actorId,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> nameExists(String name, {String? excludeCategoryId}) async {
    try {
      return await _repository.nameExists(
        name: name,
        excludeCategoryId: excludeCategoryId,
      );
    } catch (_) {
      return false;
    }
  }
}

final categoryOperationsProvider = StateNotifierProvider.family<
    CategoryOperationsNotifier, AsyncValue<void>, CategoryKind>((ref, kind) {
  return CategoryOperationsNotifier(ref, kind);
});
