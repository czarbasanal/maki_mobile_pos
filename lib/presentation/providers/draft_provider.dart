import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/data/repositories/draft_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

// ==================== REPOSITORY PROVIDER ====================

/// Provides the DraftRepository instance.
final draftRepositoryProvider = Provider<DraftRepository>((ref) {
  return DraftRepositoryImpl();
});

// ==================== DRAFT QUERIES ====================

/// Provides active (non-converted) drafts as a real-time stream.
final activeDraftsProvider = StreamProvider<List<DraftEntity>>((ref) {
  final repository = ref.watch(draftRepositoryProvider);
  return repository.watchActiveDrafts();
});

/// Provides active drafts for a specific user.
final userActiveDraftsProvider =
    StreamProvider.family<List<DraftEntity>, String>((ref, userId) {
  final repository = ref.watch(draftRepositoryProvider);
  return repository.watchActiveDrafts(createdBy: userId);
});

/// Provides a single draft by ID as a real-time stream.
final draftByIdStreamProvider =
    StreamProvider.family<DraftEntity?, String>((ref, draftId) {
  final repository = ref.watch(draftRepositoryProvider);
  return repository.watchDraft(draftId);
});

/// Provides a single draft by ID (one-time fetch).
final draftByIdProvider =
    FutureProvider.family<DraftEntity?, String>((ref, draftId) async {
  final repository = ref.watch(draftRepositoryProvider);
  return repository.getDraftById(draftId);
});

/// Provides all drafts including converted ones.
final allDraftsProvider =
    FutureProvider.family<List<DraftEntity>, AllDraftsParams>(
        (ref, params) async {
  final repository = ref.watch(draftRepositoryProvider);
  return repository.getAllDrafts(
    createdBy: params.createdBy,
    includeConverted: params.includeConverted,
    limit: params.limit,
  );
});

/// Provides active draft count.
final activeDraftCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(draftRepositoryProvider);
  return repository.getActiveDraftCount();
});

/// Provides active draft count for a specific user.
final userActiveDraftCountProvider =
    FutureProvider.family<int, String>((ref, userId) async {
  final repository = ref.watch(draftRepositoryProvider);
  return repository.getActiveDraftCount(createdBy: userId);
});

// ==================== DRAFT OPERATIONS ====================

/// Notifier for draft operations (create, update, delete, convert).
class DraftOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final DraftRepository _repository;
  final Ref _ref;

  DraftOperationsNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  /// Creates a new draft.
  Future<DraftEntity?> createDraft(DraftEntity draft) async {
    state = const AsyncValue.loading();
    try {
      final created = await _repository.createDraft(draft);
      state = const AsyncValue.data(null);
      _invalidateDraftProviders();
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Updates an existing draft.
  Future<DraftEntity?> updateDraft({
    required DraftEntity draft,
    required String updatedBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _repository.updateDraft(
        draft: draft,
        updatedBy: updatedBy,
      );
      state = const AsyncValue.data(null);
      _invalidateDraftProviders();
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Updates draft items only.
  Future<DraftEntity?> updateDraftItems({
    required String draftId,
    required List<SaleItemEntity> items,
    required String updatedBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _repository.updateDraftItems(
        draftId: draftId,
        items: items,
        updatedBy: updatedBy,
      );
      state = const AsyncValue.data(null);
      _ref.invalidate(draftByIdProvider(draftId));
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Updates draft name.
  Future<DraftEntity?> updateDraftName({
    required String draftId,
    required String name,
    required String updatedBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _repository.updateDraftName(
        draftId: draftId,
        name: name,
        updatedBy: updatedBy,
      );
      state = const AsyncValue.data(null);
      _ref.invalidate(draftByIdProvider(draftId));
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Marks a draft as converted to a sale.
  Future<DraftEntity?> markAsConverted({
    required String draftId,
    required String saleId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _repository.markDraftAsConverted(
        draftId: draftId,
        saleId: saleId,
      );
      state = const AsyncValue.data(null);
      _invalidateDraftProviders();
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Deletes a draft.
  Future<bool> deleteDraft(String draftId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteDraft(draftId);
      state = const AsyncValue.data(null);
      _invalidateDraftProviders();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Checks if a draft name already exists.
  Future<bool> draftNameExists({
    required String name,
    String? excludeDraftId,
  }) async {
    try {
      return await _repository.draftNameExists(
        name: name,
        excludeDraftId: excludeDraftId,
      );
    } catch (e) {
      return false;
    }
  }

  /// Deletes old converted drafts.
  Future<int> deleteOldConvertedDrafts(DateTime olderThan) async {
    try {
      final count = await _repository.deleteOldConvertedDrafts(olderThan);
      _invalidateDraftProviders();
      return count;
    } catch (e) {
      return 0;
    }
  }

  void _invalidateDraftProviders() {
    _ref.invalidate(activeDraftsProvider);
    _ref.invalidate(activeDraftCountProvider);
  }
}

/// Provider for draft operations.
final draftOperationsProvider =
    StateNotifierProvider<DraftOperationsNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(draftRepositoryProvider);
  return DraftOperationsNotifier(repository, ref);
});

// ==================== SELECTED DRAFT ====================

/// Currently selected draft for editing.
/// This is used when loading a draft into the cart for editing.
final selectedDraftProvider = StateProvider<DraftEntity?>((ref) => null);

// ==================== PARAMETER CLASSES ====================

/// Parameters for all drafts query.
class AllDraftsParams {
  final String? createdBy;
  final bool includeConverted;
  final int limit;

  const AllDraftsParams({
    this.createdBy,
    this.includeConverted = false,
    this.limit = 100,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AllDraftsParams &&
        other.createdBy == createdBy &&
        other.includeConverted == includeConverted &&
        other.limit == limit;
  }

  @override
  int get hashCode =>
      createdBy.hashCode ^ includeConverted.hashCode ^ limit.hashCode;
}
