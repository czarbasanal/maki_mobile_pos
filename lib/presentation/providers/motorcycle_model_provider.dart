import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/utils/motorcycle_model_name.dart';
import 'package:maki_mobile_pos/data/repositories/motorcycle_model_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/motorcycle_model_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

/// Provides the [MotorcycleModelRepository] bound to `motorcycle_models`.
final motorcycleModelRepositoryProvider =
    Provider<MotorcycleModelRepository>((ref) {
  return MotorcycleModelRepositoryImpl(firestore: ref.watch(firestoreProvider));
});

/// Streams active models for the cashier-facing picker. Auth-gated.
final activeMotorcycleModelsProvider =
    StreamProvider<List<MotorcycleModelEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(motorcycleModelRepositoryProvider).watchActive();
  });
});

/// Streams all models (active + inactive) for the admin editor.
final allMotorcycleModelsProvider =
    StreamProvider<List<MotorcycleModelEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(motorcycleModelRepositoryProvider).watchAll();
  });
});

/// Mutations for the motorcycle model list. Permission is checked at the route
/// layer for the admin editor; pick-or-add creation is allowed for any user.
class MotorcycleModelOperationsNotifier
    extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  MotorcycleModelOperationsNotifier(this._ref)
      : super(const AsyncValue.data(null));

  MotorcycleModelRepository get _repo =>
      _ref.read(motorcycleModelRepositoryProvider);

  String _requireUserId() {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) throw const UnauthenticatedException();
    return user.id;
  }

  /// Pick-or-add core: reuse an existing model (reactivating if archived),
  /// else create. Returns the canonical name to store on the ticket, or null
  /// on blank input / failure.
  Future<String?> resolveOrCreate(String rawName) async {
    final canonical = canonicalModelName(rawName);
    if (canonical.isEmpty) return null;
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      final existing =
          await _repo.findByNormalizedKey(normalizedModelKey(rawName));
      if (existing != null) {
        if (!existing.isActive) {
          await _repo.setActive(
              id: existing.id, active: true, updatedBy: actorId);
        }
        state = const AsyncValue.data(null);
        return existing.name;
      }
      final created = await _repo.create(
        model: MotorcycleModelEntity(
          id: '',
          name: canonical,
          isActive: true,
          createdAt: DateTime.now(),
        ),
        createdBy: actorId,
      );
      state = const AsyncValue.data(null);
      return created.name;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<MotorcycleModelEntity?> create(
      {required MotorcycleModelEntity model}) async {
    state = const AsyncValue.loading();
    try {
      final created =
          await _repo.create(model: model, createdBy: _requireUserId());
      state = const AsyncValue.data(null);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<MotorcycleModelEntity?> update(
      {required MotorcycleModelEntity model}) async {
    state = const AsyncValue.loading();
    try {
      final updated =
          await _repo.update(model: model, updatedBy: _requireUserId());
      state = const AsyncValue.data(null);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deactivate(String id) => _setActive(id, false);
  Future<bool> reactivate(String id) => _setActive(id, true);

  Future<bool> _setActive(String id, bool active) async {
    state = const AsyncValue.loading();
    try {
      await _repo.setActive(id: id, active: active, updatedBy: _requireUserId());
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final motorcycleModelOperationsProvider = StateNotifierProvider<
    MotorcycleModelOperationsNotifier, AsyncValue<void>>((ref) {
  return MotorcycleModelOperationsNotifier(ref);
});
