import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/data/repositories/draft_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/domain/usecases/draft/delete_draft_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/draft/save_draft_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/draft/update_draft_usecase.dart';

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

// ==================== USE CASE PROVIDERS ====================

final saveDraftUseCaseProvider = Provider<SaveDraftUseCase>((ref) {
  return SaveDraftUseCase(repository: ref.watch(draftRepositoryProvider));
});

final updateDraftUseCaseProvider = Provider<UpdateDraftUseCase>((ref) {
  return UpdateDraftUseCase(repository: ref.watch(draftRepositoryProvider));
});

final deleteDraftUseCaseProvider = Provider<DeleteDraftUseCase>((ref) {
  return DeleteDraftUseCase(repository: ref.watch(draftRepositoryProvider));
});

// ==================== DRAFT OPERATIONS ====================

/// Notifier for draft operations.
///
/// Mutations (save / update / delete) flow through use cases that own the
/// permission check + owner-or-admin guard. Convenience methods
/// (updateDraftItems, updateDraftName) construct the desired DraftEntity
/// and route through [updateDraft] so guards apply uniformly.
/// `markAsConverted` stays a direct repo call — it's invoked from
/// [ProcessSaleUseCase] which has already gated the operation.
class DraftOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final DraftRepository _repository;
  final SaveDraftUseCase _saveUseCase;
  final UpdateDraftUseCase _updateUseCase;
  final DeleteDraftUseCase _deleteUseCase;
  final Ref _ref;

  DraftOperationsNotifier({
    required DraftRepository repository,
    required SaveDraftUseCase saveUseCase,
    required UpdateDraftUseCase updateUseCase,
    required DeleteDraftUseCase deleteUseCase,
    required Ref ref,
  })  : _repository = repository,
        _saveUseCase = saveUseCase,
        _updateUseCase = updateUseCase,
        _deleteUseCase = deleteUseCase,
        _ref = ref,
        super(const AsyncValue.data(null));

  Future<DraftEntity?> createDraft({
    required UserEntity actor,
    required DraftEntity draft,
  }) async {
    state = const AsyncValue.loading();
    final result = await _saveUseCase.execute(actor: actor, draft: draft);
    if (result.success) {
      state = const AsyncValue.data(null);
      _invalidateDraftProviders();
      return result.data;
    } else {
      state = AsyncValue.error(
        result.errorMessage ?? 'Failed to save draft',
        StackTrace.current,
      );
      return null;
    }
  }

  Future<DraftEntity?> updateDraft({
    required UserEntity actor,
    required DraftEntity draft,
  }) async {
    state = const AsyncValue.loading();
    final result = await _updateUseCase.execute(actor: actor, draft: draft);
    if (result.success) {
      state = const AsyncValue.data(null);
      _invalidateDraftProviders();
      _ref.invalidate(draftByIdProvider(draft.id));
      return result.data;
    } else {
      state = AsyncValue.error(
        result.errorMessage ?? 'Failed to update draft',
        StackTrace.current,
      );
      return null;
    }
  }

  /// Convenience: update items via [updateDraft] with a fresh DraftEntity.
  Future<DraftEntity?> updateDraftItems({
    required UserEntity actor,
    required DraftEntity draft,
    required List<SaleItemEntity> items,
  }) async {
    return updateDraft(actor: actor, draft: draft.copyWith(items: items));
  }

  /// Convenience: update name via [updateDraft] with a fresh DraftEntity.
  Future<DraftEntity?> updateDraftName({
    required UserEntity actor,
    required DraftEntity draft,
    required String name,
  }) async {
    return updateDraft(actor: actor, draft: draft.copyWith(name: name));
  }

  /// Marks a draft as converted. Internal sale-flow side-effect, not user-
  /// driven — process_sale_usecase already gated the operation.
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

  Future<bool> deleteDraft({
    required UserEntity actor,
    required String draftId,
  }) async {
    state = const AsyncValue.loading();
    final result =
        await _deleteUseCase.execute(actor: actor, draftId: draftId);
    if (result.success) {
      state = const AsyncValue.data(null);
      _invalidateDraftProviders();
      return true;
    } else {
      state = AsyncValue.error(
        result.errorMessage ?? 'Failed to delete draft',
        StackTrace.current,
      );
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
  return DraftOperationsNotifier(
    repository: ref.watch(draftRepositoryProvider),
    saveUseCase: ref.watch(saveDraftUseCaseProvider),
    updateUseCase: ref.watch(updateDraftUseCaseProvider),
    deleteUseCase: ref.watch(deleteDraftUseCaseProvider),
    ref: ref,
  );
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
