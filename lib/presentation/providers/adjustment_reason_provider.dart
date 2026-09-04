import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/adjustment_reason_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/adjustment_reason_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

// ==================== REPOSITORY PROVIDER ====================

/// Provides the [AdjustmentReasonRepository] bound to the `adjustment_reasons` collection.
final adjustmentReasonRepositoryProvider = Provider<AdjustmentReasonRepository>((ref) {
  return AdjustmentReasonRepositoryImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

// ==================== ADJUSTMENT REASON QUERIES ====================

/// Streams active adjustment reasons. Auth-gated so it does not emit a
/// permission-denied error before the user's session is warm.
final activeAdjustmentReasonsProvider =
    StreamProvider<List<AdjustmentReasonEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(adjustmentReasonRepositoryProvider).watchActive();
  });
});

/// Streams all adjustment reasons (active + inactive) for the admin editor screen.
final allAdjustmentReasonsProvider = StreamProvider<List<AdjustmentReasonEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(adjustmentReasonRepositoryProvider).watchAll();
  });
});

// ==================== ADJUSTMENT REASON OPERATIONS ====================

/// Notifier for adjustment reason mutations. Permission is checked at the route layer;
/// this notifier does not duplicate that gate.
class AdjustmentReasonOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  AdjustmentReasonOperationsNotifier(this._ref)
      : super(const AsyncValue.data(null));

  AdjustmentReasonRepository get _repository =>
      _ref.read(adjustmentReasonRepositoryProvider);

  String _requireUserId() {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      throw const UnauthenticatedException();
    }
    return user.id;
  }

  Future<AdjustmentReasonEntity?> create({
    required AdjustmentReasonEntity reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      final created = await _repository.createAdjustmentReason(
        reason: reason,
        createdBy: actorId,
      );
      state = const AsyncValue.data(null);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<AdjustmentReasonEntity?> update({
    required AdjustmentReasonEntity reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      final updated = await _repository.updateAdjustmentReason(
        reason: reason,
        updatedBy: actorId,
      );
      state = const AsyncValue.data(null);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deactivate(String reasonId) =>
      _setActive(reasonId: reasonId, active: false);

  Future<bool> reactivate(String reasonId) =>
      _setActive(reasonId: reasonId, active: true);

  Future<bool> _setActive({
    required String reasonId,
    required bool active,
  }) async {
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      await _repository.setActive(
        reasonId: reasonId,
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

  /// Permanently deletes the entry. Returns true on success.
  Future<bool> delete(String reasonId) async {
    state = const AsyncValue.loading();
    try {
      _requireUserId();
      await _repository.deleteReason(reasonId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Seeds the default adjustment reasons. Called once on app startup.
  Future<void> seedDefaults() async {
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      await _repository.seedDefaults(actorId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final adjustmentReasonOperationsProvider =
    StateNotifierProvider<AdjustmentReasonOperationsNotifier, AsyncValue<void>>(
        (ref) {
  return AdjustmentReasonOperationsNotifier(ref);
});
