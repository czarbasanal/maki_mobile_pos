import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/tag_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/tag_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

// ==================== REPOSITORY PROVIDER ====================

/// Provides the [TagRepository] bound to the `product_tags` collection.
final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepositoryImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

// ==================== TAG QUERIES ====================

/// Streams active tags. Auth-gated so it does not emit a
/// permission-denied error before the user's session is warm.
final activeTagsProvider =
    StreamProvider<List<TagEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(tagRepositoryProvider).watchActive();
  });
});

/// Streams all tags (active + inactive) for the admin editor screen.
final allTagsProvider = StreamProvider<List<TagEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(tagRepositoryProvider).watchAll();
  });
});

// ==================== TAG OPERATIONS ====================

/// Notifier for tag mutations. Permission is checked at the route layer;
/// this notifier does not duplicate that gate.
class TagOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  TagOperationsNotifier(this._ref)
      : super(const AsyncValue.data(null));

  TagRepository get _repository => _ref.read(tagRepositoryProvider);

  String _requireUserId() {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      throw const UnauthenticatedException();
    }
    return user.id;
  }

  Future<TagEntity?> create({required TagEntity tag}) async {
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      final created = await _repository.createTag(
        tag: tag,
        createdBy: actorId,
      );
      state = const AsyncValue.data(null);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<TagEntity?> update({required TagEntity tag}) async {
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      final updated = await _repository.updateTag(
        tag: tag,
        updatedBy: actorId,
      );
      state = const AsyncValue.data(null);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deactivate(String tagId) =>
      _setActive(tagId: tagId, active: false);

  Future<bool> reactivate(String tagId) =>
      _setActive(tagId: tagId, active: true);

  Future<bool> _setActive({
    required String tagId,
    required bool active,
  }) async {
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      await _repository.setActive(
        tagId: tagId,
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
  Future<bool> delete(String tagId) async {
    state = const AsyncValue.loading();
    try {
      _requireUserId();
      await _repository.deleteTag(tagId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

}

final tagOperationsProvider =
    StateNotifierProvider<TagOperationsNotifier, AsyncValue<void>>(
        (ref) {
  return TagOperationsNotifier(ref);
});
