import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/mechanic_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/mechanic_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

// ==================== REPOSITORY PROVIDER ====================

/// Provides the [MechanicRepository] bound to the `mechanics` collection.
final mechanicRepositoryProvider = Provider<MechanicRepository>((ref) {
  return MechanicRepositoryImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

// ==================== MECHANIC QUERIES ====================

/// Streams active mechanics. Auth-gated so it does not emit a
/// permission-denied error before the user's session is warm. Used by the
/// cashier-facing mechanic picker.
final activeMechanicsProvider =
    StreamProvider<List<MechanicEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(mechanicRepositoryProvider).watchActive();
  });
});

/// Streams all mechanics (active + inactive) for the admin editor screen.
final allMechanicsProvider = StreamProvider<List<MechanicEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(mechanicRepositoryProvider).watchAll();
  });
});

// ==================== MECHANIC OPERATIONS ====================

/// Notifier for mechanic mutations. Permission is checked at the route layer;
/// this notifier does not duplicate that gate.
class MechanicOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  MechanicOperationsNotifier(this._ref)
      : super(const AsyncValue.data(null));

  MechanicRepository get _repository => _ref.read(mechanicRepositoryProvider);

  String _requireUserId() {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      throw const UnauthenticatedException();
    }
    return user.id;
  }

  Future<MechanicEntity?> create({required MechanicEntity mechanic}) async {
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      final created = await _repository.createMechanic(
        mechanic: mechanic,
        createdBy: actorId,
      );
      state = const AsyncValue.data(null);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<MechanicEntity?> update({required MechanicEntity mechanic}) async {
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      final updated = await _repository.updateMechanic(
        mechanic: mechanic,
        updatedBy: actorId,
      );
      state = const AsyncValue.data(null);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deactivate(String mechanicId) =>
      _setActive(mechanicId: mechanicId, active: false);

  Future<bool> reactivate(String mechanicId) =>
      _setActive(mechanicId: mechanicId, active: true);

  Future<bool> _setActive({
    required String mechanicId,
    required bool active,
  }) async {
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      await _repository.setActive(
        mechanicId: mechanicId,
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

  Future<bool> nameExists(String name, {String? excludeMechanicId}) async {
    try {
      return await _repository.nameExists(
        name: name,
        excludeMechanicId: excludeMechanicId,
      );
    } catch (_) {
      return false;
    }
  }
}

final mechanicOperationsProvider =
    StateNotifierProvider<MechanicOperationsNotifier, AsyncValue<void>>(
        (ref) {
  return MechanicOperationsNotifier(ref);
});
