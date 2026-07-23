import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/user_provider.dart';

/// Live status of the signed-in user's OWN `users/{uid}` doc.
enum AccountStatus { active, deactivated, deleted }

/// Streams the signed-in user's own user doc as an [AccountStatus] for the
/// whole signed-in session.
///
/// Rules let a user read their own doc regardless of isActive
/// (firestore.rules users block), so this listener keeps working after
/// deactivation. When the doc is deleted, `watchUser` maps the
/// `exists == false` snapshot to null → [AccountStatus.deleted]; a
/// permission-denied stream error is treated the same (deletion implies prior
/// deactivation — tail case).
///
/// While signed out this emits nothing (authGatedStream returns an empty
/// stream), and it re-subscribes on the next sign-in because it watches
/// [currentUserProvider] through authGatedStream.
final accountStatusProvider = StreamProvider<AccountStatus>((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return authGatedStream(ref, (user) async* {
    try {
      await for (final doc in repository.watchUser(user.id)) {
        if (doc == null) {
          yield AccountStatus.deleted;
        } else if (doc.isActive) {
          yield AccountStatus.active;
        } else {
          yield AccountStatus.deactivated;
        }
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        yield AccountStatus.deleted;
      } else {
        rethrow;
      }
    }
  });
});
