import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
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

/// Countdown length for the deactivation modal (spec-bound: 10 seconds).
const accountDeactivationCountdownSeconds = 10;

/// UI state for the blocking "Account deactivated" modal.
class AccountDeactivationState extends Equatable {
  /// Whether the blocking modal is showing.
  final bool visible;

  /// Seconds left on the countdown; null in the doc-gone (immediate) variant.
  final int? secondsLeft;

  const AccountDeactivationState.hidden()
      : visible = false,
        secondsLeft = null;

  const AccountDeactivationState.countdown(int seconds)
      : visible = true,
        secondsLeft = seconds;

  const AccountDeactivationState.immediate()
      : visible = true,
        secondsLeft = null;

  @override
  List<Object?> get props => [visible, secondsLeft];
}

/// Owns the countdown timer + sign-out sequence for mid-session
/// deactivation/deletion. Fed by [accountStatusProvider]; reset on any
/// sign-out transition so the modal never leaks onto the login screen and a
/// normal sign-out tears the machinery down without showing the modal.
class AccountDeactivationController
    extends StateNotifier<AccountDeactivationState> {
  AccountDeactivationController({required Future<void> Function() signOut})
      : _signOut = signOut,
        super(const AccountDeactivationState.hidden());

  final Future<void> Function() _signOut;
  Timer? _timer;
  bool _fired = false;
  bool _signedOut = false;

  /// Set by [reset] (a normal sign-out transition) and cleared by
  /// [onSignedIn]. While true, [onDeactivated]/[onDeleted] are ignored — this
  /// closes the race where a trailing `accountStatusProvider` emission (e.g.
  /// the doc-watcher's permission-denied → deleted mapping) arrives *after*
  /// the user has already signed out normally. Correctness here must not
  /// depend on the relative ordering of the two `ref.listen` callbacks below;
  /// this flag makes it explicit state instead of an ordering assumption.
  bool _signedOutSession = false;

  /// isActive flipped false → show the modal with a 10s countdown, then sign
  /// out. Idempotent: repeated stream emissions never restart the countdown.
  void onDeactivated() {
    if (_signedOutSession || _fired) return;
    _fired = true;
    state = const AccountDeactivationState.countdown(
        accountDeactivationCountdownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final seconds = (state.secondsLeft ?? 1) - 1;
      if (seconds <= 0) {
        timer.cancel();
        state = const AccountDeactivationState.countdown(0);
        _doSignOut();
      } else {
        state = AccountDeactivationState.countdown(seconds);
      }
    });
  }

  /// Own doc gone (or stream permission-denied) → same modal, immediate
  /// sign-out. Escalates a running countdown without double-firing.
  void onDeleted() {
    if (_signedOutSession) return;
    _fired = true;
    _timer?.cancel();
    _timer = null;
    state = const AccountDeactivationState.immediate();
    _doSignOut();
  }

  /// Any sign-out transition (ours or a normal one) tears everything down and
  /// marks the session as signed-out, so any deactivation/deletion event
  /// arriving after this point (trailing stream noise) is ignored until the
  /// next sign-in.
  void reset() {
    _timer?.cancel();
    _timer = null;
    _fired = false;
    _signedOut = false;
    _signedOutSession = true;
    state = const AccountDeactivationState.hidden();
  }

  /// Clears the post-sign-out guard set by [reset] once a new user signs in,
  /// so the next session's deactivation/deletion events are handled normally.
  void onSignedIn() {
    _signedOutSession = false;
  }

  void _doSignOut() {
    if (_signedOut) return;
    _signedOut = true;
    _signOut();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final accountDeactivationControllerProvider = StateNotifierProvider<
    AccountDeactivationController, AccountDeactivationState>((ref) {
  final controller = AccountDeactivationController(
    signOut: () async {
      try {
        await ref.read(authActionsProvider).signOut();
      } catch (_) {
        // The use-case path can throw for an already-deactivated/deleted user
        // — fall back to the raw repository sign-out so the session always
        // ends. If even that fails the next app start lands on login anyway
        // (the profile is inactive or gone).
        try {
          await ref.read(authRepositoryProvider).signOut();
        } catch (_) {}
      }
    },
  );

  ref.listen<AsyncValue<AccountStatus>>(accountStatusProvider, (prev, next) {
    final status = next.valueOrNull;
    if (status == AccountStatus.deactivated) {
      controller.onDeactivated();
    } else if (status == AccountStatus.deleted) {
      controller.onDeleted();
    }
  });

  ref.listen<AsyncValue<UserEntity?>>(currentUserProvider, (prev, next) {
    final wasSignedIn = prev?.valueOrNull != null;
    final nowSignedOut = next.valueOrNull == null && !next.isLoading;
    if (wasSignedIn && nowSignedOut) {
      controller.reset();
    } else if (next.valueOrNull != null) {
      controller.onSignedIn();
    }
  });

  return controller;
});
