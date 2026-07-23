# User Deletion + Mid-Session Deactivation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let admins permanently delete already-deactivated users from both surfaces (Firestore doc only), tighten the users `allow delete` rule to enforce deactivate-first + no-self-delete server-side, make mid-session deactivation/deletion take effect immediately via a blocking "Account deactivated" modal with a 10-second countdown and auto sign-out on both surfaces, and add an admin script to clean up the orphaned Firebase Auth credential.

**Architecture:** Mobile follows the existing clean-architecture chain (UserRepository → DeleteUserUseCase with permission/guards/logging → UserOperationsNotifier → users screen popup action) plus a new Riverpod stream of the signed-in user's own `users/{uid}` doc feeding a StateNotifier that owns the countdown timer and sign-out, rendered as a state-driven blocking overlay above the router's Navigator. Web mirrors it (FirestoreUserRepository.delete → guard → useDeleteUser mutation → UsersListPage row action) plus an `AccountDeactivationGuard` component mounted in AdminShell that subscribes via `watchOne` for the whole signed-in session. Rules and the rules test suite are tightened; a firebase-admin script deletes the Auth credential only after the Firestore doc is gone.

**Tech Stack:** Flutter + Riverpod + mocktail + fake_cloud_firestore (root); React + Vite + TypeScript + TanStack Query + Zustand + Vitest + Testing Library (`web_admin/`); Firestore security rules + `@firebase/rules-unit-testing` (`tools/firestore-rules-test/`); Node + firebase-admin (`scripts/`).

**Spec:** docs/superpowers/specs/2026-07-23-user-deletion-design.md

## Global Constraints

Binding values from the spec — do not change these:

- **Countdown:** 10 seconds, shown in the modal, then automatic sign-out (landing on login).
- **Modal copy (exact, both surfaces):** title **"Account deactivated"**, body **"Your account has been deactivated by an administrator. You will be signed out."** Blocking, non-dismissable.
- **Delete gating:** delete action only shown/enabled for `isActive == false` targets; **no self-delete**. Delete removes the `users/{uid}` Firestore doc only (no cascade, historical records keep denormalized uid/name strings). Confirm dialog before delete (destructive style), naming the user.
- **Doc-gone mid-session** (snapshot `exists == false`) **or stream permission-denied:** same modal, sign-out fires **immediately** (no countdown).
- **Normal sign-out** while the watcher is alive tears it down without showing the modal.
- **Must not double-fire** if the stream emits repeatedly.
- **Rules text (exact):**
  ```
  allow delete: if isAdmin() && isActiveUser()
    && request.auth.uid != userId
    && resource.data.isActive == false;
  ```
- **Script:** `scripts/delete-auth-user.mjs` (firebase-admin, `applicationDefault` credentials, `PROJECT_ID` `maki-mobile-pos`, same conventions as the backfills): `node delete-auth-user.mjs <email-or-uid>` — looks up the auth account, **ABORTS if a `users/{uid}` doc still exists** (in-app delete first), prints what it found, requires `--apply` to actually delete the credential.
- **Branch:** `feat/user-deletion` (already checked out).
- **Test commands:** mobile — `flutter test`, `flutter analyze` (repo root); web — `npm run typecheck`, `npm run test`, `npm run build` (run inside `web_admin/`); rules — `cd tools/firestore-rules-test && npm test` (Firestore emulator via `firebase emulators:exec`, needs Java).
- **Deploy:** hosting + **firestore rules need the user's explicit go-ahead** (production-affecting); mobile rides the next APK.
- Commits end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

**Design decisions taken where the spec left latitude** (verified against the code):

1. **Mobile modal mechanism:** there is no `navigatorKey` anywhere in `lib/` (verified by grep). Instead of adding one and imperatively showing a dialog (double-fire risk, hard to test), the modal is a **state-driven overlay** (`Stack` + `ModalBarrier` + card) rendered from the `MaterialApp.router` `builder` slot in `app_mobile.dart` — above the router's Navigator, so it covers every screen, is non-dismissable by construction, cannot double-show, and disappears automatically when the controller resets on sign-out. The existing `_OfflineBanner` in the same builder slot proves Theme/Directionality are available there.
2. **Web subscription home:** the whole signed-in session renders inside `AdminShell` (mounted under `ProtectedRoute` in `routes.tsx`), so the watcher lives in an `AccountDeactivationGuard` component mounted from `AdminShell`. Teardown on normal sign-out is automatic: uid flips to null / shell unmounts → effect cleanup unsubscribes and clears the timer.
3. **Sign-out for a deactivated mobile user:** `SignOutUseCase` logs logout *before* `repository.signOut()`, but `ActivityLogger.log` swallows every error (`lib/services/activity_logger.dart` — "Don't throw - logging should never break the app"), so the denied log write cannot block sign-out. The controller still falls back to `authRepositoryProvider.signOut()` if the use-case path throws.
4. **Web repo delegation test:** the web suite has no Firestore-mocking repo tests (verified — no `vi.mock('firebase...')` anywhere); delegation is covered by the UsersListPage test asserting `repo.delete` is called with the target id through the real hook.

---

### Task 1: Mobile — repository `deleteUser` + `DeleteUserUseCase`

**Files:**
- Modify: `lib/domain/repositories/user_repository.dart`
- Modify: `lib/data/repositories/user_repository_impl.dart`
- Create: `lib/domain/usecases/user/delete_user_usecase.dart`
- Test: `test/data/repositories/user_repository_impl_delete_test.dart` (create)
- Test: `test/domain/usecases/user/delete_user_usecase_test.dart` (create)

**Interfaces:**
- Consumes: `UserRepository.getUserById(String)`, `ActivityLogger.log(...)`, `assertPermission(UserEntity, Permission)`, `UseCaseResult` (`successVoid` / `failure` / `fromException`).
- Produces: `Future<void> deleteUser(String userId)` on `UserRepository`; `class DeleteUserUseCase { Future<UseCaseResult<void>> execute({required UserEntity actor, required String userId}) }`.

**Steps:**

- [ ] Write the failing repo test at `test/data/repositories/user_repository_impl_delete_test.dart`. Note: `UserRepositoryImpl`'s constructor eagerly resolves `FirebaseAuth.instance` when no `auth` is passed, which throws without a Firebase app — so pass a bare mocktail mock (delete never touches auth):

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/user_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late UserRepositoryImpl repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = UserRepositoryImpl(
      firestore: fakeFirestore,
      auth: _MockFirebaseAuth(),
    );
  });

  test('deleteUser removes the users/{uid} document', () async {
    await fakeFirestore.collection('users').doc('u-1').set({
      'email': 'x@test',
      'displayName': 'X',
      'role': 'cashier',
      'isActive': false,
      'createdAt': Timestamp.now(),
    });

    await repository.deleteUser('u-1');

    final doc = await fakeFirestore.collection('users').doc('u-1').get();
    expect(doc.exists, isFalse);
  });

  test('deleteUser on a missing doc completes without error', () async {
    await expectLater(repository.deleteUser('missing'), completes);
  });
}
```

- [ ] Write the failing use-case test at `test/domain/usecases/user/delete_user_usecase_test.dart` (mirrors `update_user_usecase_test.dart` idioms):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/user_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/user/delete_user_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockActivityLogRepository extends Mock implements ActivityLogRepository {
}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _user(
  UserRole role, {
  String? id,
  bool isActive = true,
}) =>
    UserEntity(
      id: id ?? 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: isActive,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockUserRepository repo;
  late _MockActivityLogRepository logRepo;
  late DeleteUserUseCase useCase;

  setUp(() {
    repo = _MockUserRepository();
    logRepo = _MockActivityLogRepository();
    useCase = DeleteUserUseCase(
      repository: repo,
      logger: ActivityLogger(logRepo),
    );

    when(() => repo.deleteUser(any())).thenAnswer((_) async {});
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  test('admin deletes an inactive user and the deletion is logged', () async {
    when(() => repo.getUserById('u-c1'))
        .thenAnswer((_) async => _user(UserRole.cashier, id: 'u-c1', isActive: false));

    final result = await useCase.execute(
      actor: _user(UserRole.admin),
      userId: 'u-c1',
    );

    expect(result.success, isTrue);
    verify(() => repo.deleteUser('u-c1')).called(1);
    verify(() => logRepo.logActivity(any())).called(1);
  });

  test('rejects an ACTIVE target (deactivate-first)', () async {
    when(() => repo.getUserById('u-c1'))
        .thenAnswer((_) async => _user(UserRole.cashier, id: 'u-c1'));

    final result = await useCase.execute(
      actor: _user(UserRole.admin),
      userId: 'u-c1',
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'active-target');
    verifyNever(() => repo.deleteUser(any()));
  });

  test('rejects self-delete', () async {
    final admin = _user(UserRole.admin);

    final result = await useCase.execute(actor: admin, userId: admin.id);

    expect(result.success, isFalse);
    expect(result.errorCode, 'self-delete');
    verifyNever(() => repo.deleteUser(any()));
  });

  test('rejects a missing target', () async {
    when(() => repo.getUserById('ghost')).thenAnswer((_) async => null);

    final result = await useCase.execute(
      actor: _user(UserRole.admin),
      userId: 'ghost',
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'not-found');
    verifyNever(() => repo.deleteUser(any()));
  });

  test('rejects a non-admin actor (Permission.deleteUser)', () async {
    final result = await useCase.execute(
      actor: _user(UserRole.staff),
      userId: 'u-c1',
    );

    expect(result.success, isFalse);
    verifyNever(() => repo.deleteUser(any()));
  });
}
```

  Assumption: `UseCaseResult` exposes `errorCode` (it does — `update_user_usecase.dart` constructs `UseCaseResult.failure(message: ..., code: ...)` and `AuthNotifier` reads `result.errorCode`). If the getter is named differently in `lib/domain/usecases/base/use_case.dart`, read that file and use its actual name in both test and assertions.

- [ ] Run: `flutter test test/data/repositories/user_repository_impl_delete_test.dart test/domain/usecases/user/delete_user_usecase_test.dart` — **expected failure:** compile errors (`deleteUser` not defined on `UserRepository`; `delete_user_usecase.dart` does not exist).

- [ ] Implement. In `lib/domain/repositories/user_repository.dart`, after `reactivateUser` (before `// ==================== UTILITY ====================`), add:

```dart
  // ==================== DELETE ====================

  /// Deletes a user's Firestore document. Deactivate-first and no-self-delete
  /// are enforced by [DeleteUserUseCase] and by Firestore rules; this is the
  /// raw doc delete. The Firebase Auth credential is NOT touched (client SDKs
  /// cannot delete another user's credential — see scripts/delete-auth-user.mjs).
  Future<void> deleteUser(String userId);
```

- [ ] In `lib/data/repositories/user_repository_impl.dart`, after `reactivateUser` (before `// ==================== UTILITY ====================`), add:

```dart
  // ==================== DELETE ====================

  @override
  Future<void> deleteUser(String userId) async {
    try {
      await _usersRef.doc(userId).delete();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to delete user: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
```

- [ ] Create `lib/domain/usecases/user/delete_user_usecase.dart`:

```dart
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/user_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Permanently deletes a user's Firestore document.
///
/// Permissions: [Permission.deleteUser] (admin-only on this surface).
///
/// Business guards (independent of Firestore rules, which enforce the same):
/// - You cannot delete yourself.
/// - The target must exist.
/// - The target must already be DEACTIVATED (deactivate-first).
///
/// Historical records (sales, logs) keep their denormalized uid/name strings —
/// no cascade. The Firebase Auth credential is cleaned up separately with
/// scripts/delete-auth-user.mjs.
class DeleteUserUseCase {
  final UserRepository _repository;
  final ActivityLogger _logger;

  DeleteUserUseCase({
    required UserRepository repository,
    required ActivityLogger logger,
  })  : _repository = repository,
        _logger = logger;

  Future<UseCaseResult<void>> execute({
    required UserEntity actor,
    required String userId,
  }) async {
    try {
      assertPermission(actor, Permission.deleteUser);

      if (userId == actor.id) {
        return const UseCaseResult.failure(
          message: 'You cannot delete yourself',
          code: 'self-delete',
        );
      }

      final target = await _repository.getUserById(userId);
      if (target == null) {
        return const UseCaseResult.failure(
          message: 'User not found',
          code: 'not-found',
        );
      }

      if (target.isActive) {
        return const UseCaseResult.failure(
          message: 'Deactivate this user before deleting them',
          code: 'active-target',
        );
      }

      await _repository.deleteUser(userId);

      await _logger.log(
        type: ActivityType.userManagement,
        action: 'Deleted user: ${target.displayName}',
        details: target.email,
        userId: actor.id,
        userName: actor.displayName,
        userRole: actor.role.value,
        entityId: userId,
        entityType: 'user',
      );

      return const UseCaseResult.successVoid();
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to delete user: $e');
    }
  }
}
```

- [ ] Run: `flutter test test/data/repositories/user_repository_impl_delete_test.dart test/domain/usecases/user/delete_user_usecase_test.dart` — **expected: all 7 tests pass.**
- [ ] Run: `flutter analyze` — expected: no new issues.
- [ ] Commit:

```bash
git add lib/domain/repositories/user_repository.dart lib/data/repositories/user_repository_impl.dart lib/domain/usecases/user/delete_user_usecase.dart test/data/repositories/user_repository_impl_delete_test.dart test/domain/usecases/user/delete_user_usecase_test.dart
git commit -m "feat(mobile): user delete repo method + deactivate-first use case

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Mobile — `deleteUser` on `UserOperationsNotifier`

**Files:**
- Modify: `lib/presentation/providers/user_provider.dart`
- Test: `test/presentation/providers/user_operations_delete_test.dart` (create)

**Interfaces:**
- Consumes: `DeleteUserUseCase.execute({actor, userId})` (Task 1), `activityLoggerProvider`, `userRepositoryProvider`.
- Produces: `deleteUserUseCaseProvider` (`Provider<DeleteUserUseCase>`); `Future<bool> deleteUser({required UserEntity actor, required UserEntity user})` on `UserOperationsNotifier` (invalidates `allUsersProvider`, `activeUsersProvider`, `userCountProvider`, `userByIdProvider(user.id)` on success).

**Steps:**

- [ ] Write the failing test at `test/presentation/providers/user_operations_delete_test.dart` (mirrors `user_operations_current_user_refresh_test.dart` container idiom):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/user_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/activity_log_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/user_provider.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockActivityLogRepository extends Mock
    implements ActivityLogRepository {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _user(
  UserRole role, {
  String? id,
  bool isActive = true,
}) =>
    UserEntity(
      id: id ?? 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: isActive,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockUserRepository repo;
  late _MockActivityLogRepository logRepo;
  late ProviderContainer container;

  setUp(() {
    repo = _MockUserRepository();
    logRepo = _MockActivityLogRepository();
    container = ProviderContainer(overrides: [
      userRepositoryProvider.overrideWithValue(repo),
      activityLogRepositoryProvider.overrideWithValue(logRepo),
    ]);
    addTearDown(container.dispose);

    when(() => repo.deleteUser(any())).thenAnswer((_) async {});
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  test('deleteUser returns true and calls the repo for an inactive target',
      () async {
    final target = _user(UserRole.staff, id: 'u-s1', isActive: false);
    when(() => repo.getUserById('u-s1')).thenAnswer((_) async => target);

    final ok = await container.read(userOperationsProvider.notifier).deleteUser(
          actor: _user(UserRole.admin),
          user: target,
        );

    expect(ok, isTrue);
    expect(container.read(userOperationsProvider).errorMessage, isNull);
    verify(() => repo.deleteUser('u-s1')).called(1);
  });

  test('deleteUser returns false with an error for an active target',
      () async {
    final target = _user(UserRole.staff, id: 'u-s1');
    when(() => repo.getUserById('u-s1')).thenAnswer((_) async => target);

    final ok = await container.read(userOperationsProvider.notifier).deleteUser(
          actor: _user(UserRole.admin),
          user: target,
        );

    expect(ok, isFalse);
    expect(
      container.read(userOperationsProvider).errorMessage,
      isNotNull,
    );
    verifyNever(() => repo.deleteUser(any()));
  });
}
```

  Note: `activityLogRepositoryProvider` lives in `lib/presentation/providers/activity_log_provider.dart` (same override the refresh test uses).

- [ ] Run: `flutter test test/presentation/providers/user_operations_delete_test.dart` — **expected failure:** compile error, `deleteUser` is not a method on `UserOperationsNotifier`.

- [ ] Implement in `lib/presentation/providers/user_provider.dart`:
  1. Add import: `import 'package:maki_mobile_pos/domain/usecases/user/delete_user_usecase.dart';`
  2. After `updateUserUseCaseProvider`, add:

```dart
final deleteUserUseCaseProvider = Provider<DeleteUserUseCase>((ref) {
  return DeleteUserUseCase(
    repository: ref.watch(userRepositoryProvider),
    logger: ref.watch(activityLoggerProvider),
  );
});
```

  3. Extend `UserOperationsNotifier` — new field + constructor param:

```dart
  final CreateUserUseCase _createUseCase;
  final UpdateUserUseCase _updateUseCase;
  final DeleteUserUseCase _deleteUseCase;
  final Ref _ref;

  UserOperationsNotifier({
    required CreateUserUseCase createUseCase,
    required UpdateUserUseCase updateUseCase,
    required DeleteUserUseCase deleteUseCase,
    required Ref ref,
  })  : _createUseCase = createUseCase,
        _updateUseCase = updateUseCase,
        _deleteUseCase = deleteUseCase,
        _ref = ref,
        super(const UserOperationsState());
```

  4. After `reactivateUser`, add:

```dart
  /// Permanently deletes an (already-deactivated) user's Firestore doc.
  /// Returns true on success; on failure errorMessage is set.
  Future<bool> deleteUser({
    required UserEntity actor,
    required UserEntity user,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _deleteUseCase.execute(actor: actor, userId: user.id);

    if (result.success) {
      state = state.copyWith(isLoading: false);
      _invalidateProviders();
      _ref.invalidate(userByIdProvider(user.id));
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage,
      );
      return false;
    }
  }
```

  5. Update `userOperationsProvider`:

```dart
final userOperationsProvider =
    StateNotifierProvider<UserOperationsNotifier, UserOperationsState>((ref) {
  return UserOperationsNotifier(
    createUseCase: ref.watch(createUserUseCaseProvider),
    updateUseCase: ref.watch(updateUserUseCaseProvider),
    deleteUseCase: ref.watch(deleteUserUseCaseProvider),
    ref: ref,
  );
});
```

- [ ] Run: `flutter test test/presentation/providers/user_operations_delete_test.dart test/presentation/providers/user_operations_current_user_refresh_test.dart` — **expected: all pass** (the refresh test constructs via the provider, so the new constructor param doesn't break it).
- [ ] Run: `flutter analyze` — expected clean.
- [ ] Commit:

```bash
git add lib/presentation/providers/user_provider.dart test/presentation/providers/user_operations_delete_test.dart
git commit -m "feat(mobile): deleteUser operation on UserOperationsNotifier

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Mobile — users screen delete action (inactive-only gating)

**Files:**
- Modify: `lib/presentation/mobile/widgets/users/user_list_tile.dart`
- Modify: `lib/presentation/mobile/screens/users/users_screen.dart`
- Test: `test/presentation/mobile/screens/users/users_screen_delete_test.dart` (create)

**Interfaces:**
- Consumes: `userOperationsProvider.notifier.deleteUser({actor, user})` (Task 2), `context.showConfirmDialog(...)`, `context.runWithWaiting(...)`, `context.showSuccessSnackBar` / `showErrorSnackBar`.
- Produces: `UserListTile` gains `final VoidCallback? onDelete;` (menu item "Delete" rendered only when `!user.isActive && onDelete != null`); `UsersScreen._deleteUser(UserEntity)` handler.

**Steps:**

- [ ] Write the failing widget test at `test/presentation/mobile/screens/users/users_screen_delete_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/user_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/users/users_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/activity_log_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/user_provider.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockActivityLogRepository extends Mock
    implements ActivityLogRepository {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _user({
  required String id,
  required String name,
  UserRole role = UserRole.cashier,
  bool isActive = true,
}) =>
    UserEntity(
      id: id,
      email: '$id@test',
      displayName: name,
      role: role,
      isActive: isActive,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  final admin = _user(id: 'u-admin', name: 'Admin', role: UserRole.admin);
  final activeCashier = _user(id: 'u-cash', name: 'Cashier');
  final inactiveStaff =
      _user(id: 'u-staff', name: 'Zstaff', role: UserRole.staff, isActive: false);

  late _MockUserRepository repo;
  late _MockActivityLogRepository logRepo;

  setUp(() {
    repo = _MockUserRepository();
    logRepo = _MockActivityLogRepository();
    when(() => repo.deleteUser(any())).thenAnswer((_) async {});
    when(() => repo.getUserById('u-staff'))
        .thenAnswer((_) async => inactiveStaff);
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        allUsersProvider
            .overrideWith((ref) async => [admin, activeCashier, inactiveStaff]),
        currentUserProvider.overrideWith((ref) => Stream.value(admin)),
        userRepositoryProvider.overrideWithValue(repo),
        activityLogRepositoryProvider.overrideWithValue(logRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const UsersScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    // Reveal inactive users.
    await tester.tap(find.byIcon(LucideIcons.eyeOff));
    await tester.pumpAndSettle();
  }

  testWidgets('Delete appears only in the INACTIVE user row menu',
      (tester) async {
    await pumpScreen(tester);

    // Rows sort active-first: Admin (self, chevron), Cashier, then Zstaff.
    // Two overflow menus exist (self gets none).
    expect(find.byIcon(LucideIcons.moreVertical), findsNWidgets(2));

    // Active user: no Delete.
    await tester.tap(find.byIcon(LucideIcons.moreVertical).first);
    await tester.pumpAndSettle();
    expect(find.text('Deactivate'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    await tester.tapAt(const Offset(5, 5)); // dismiss menu
    await tester.pumpAndSettle();

    // Inactive user: Reactivate + Delete.
    await tester.tap(find.byIcon(LucideIcons.moreVertical).last);
    await tester.pumpAndSettle();
    expect(find.text('Reactivate'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('confirming Delete runs the delete through the repo',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byIcon(LucideIcons.moreVertical).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Destructive confirm dialog names the user.
    expect(find.text('Delete user?'), findsOneWidget);
    expect(find.textContaining('Zstaff'), findsWidgets);

    await tester.tap(find.text('Delete')); // dialog primary action
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // waiting dialog min
    await tester.pumpAndSettle();

    verify(() => repo.deleteUser('u-staff')).called(1);
  });
}
```

- [ ] Run: `flutter test test/presentation/mobile/screens/users/users_screen_delete_test.dart` — **expected failure:** first test fails on `expect(find.text('Delete'), findsOneWidget)` (no Delete menu item exists yet); second fails at the same tap.

- [ ] Implement `UserListTile` changes in `lib/presentation/mobile/widgets/users/user_list_tile.dart`:
  1. Add field + constructor param:

```dart
  final UserEntity user;
  final bool isCurrentUser;
  final VoidCallback onTap;
  final VoidCallback? onToggleActive;
  final VoidCallback? onDelete;

  const UserListTile({
    super.key,
    required this.user,
    required this.isCurrentUser,
    required this.onTap,
    this.onToggleActive,
    this.onDelete,
  });
```

  2. Replace the trailing `PopupMenuButton<String>` (keep the surrounding `if (onToggleActive != null) ... else` structure) with:

```dart
                PopupMenuButton<String>(
                  icon: Icon(LucideIcons.moreVertical, color: muted, size: 20),
                  onSelected: (action) {
                    if (action == 'toggle') onToggleActive?.call();
                    if (action == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            user.isActive
                                ? LucideIcons.userX
                                : LucideIcons.userCheck,
                            size: 18,
                            color: user.isActive
                                ? AppColors.errorText(dark)
                                : AppColors.successText(dark),
                          ),
                          const SizedBox(width: 12),
                          Text(user.isActive ? 'Deactivate' : 'Reactivate'),
                        ],
                      ),
                    ),
                    if (!user.isActive && onDelete != null)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.trash2,
                              size: 18,
                              color: AppColors.errorText(dark),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Delete',
                              style:
                                  TextStyle(color: AppColors.errorText(dark)),
                            ),
                          ],
                        ),
                      ),
                  ],
                )
```

  Assumption: `LucideIcons.trash2` exists in `lucide_icons_flutter 3.1.14+2` (standard Lucide glyph). If the analyzer reports it missing, use `LucideIcons.trash` instead (same latitude in the web task does not apply — heroicons has `TrashIcon`).

- [ ] Implement `UsersScreen` changes in `lib/presentation/mobile/screens/users/users_screen.dart`:
  1. In `_buildUsersList`, wire the new callback on `UserListTile`:

```dart
          return UserListTile(
            user: user,
            isCurrentUser: user.id == currentUser.id,
            onTap: () => _navigateToEditUser(context, user),
            onToggleActive: user.id != currentUser.id
                ? () => _toggleUserActive(user)
                : null,
            onDelete: user.id != currentUser.id && !user.isActive
                ? () => _deleteUser(user)
                : null,
          );
```

  2. After `_toggleUserActive`, add:

```dart
  Future<void> _deleteUser(UserEntity user) async {
    final confirmed = await context.showConfirmDialog(
      title: 'Delete user?',
      message: '${user.displayName} will be permanently removed from the '
          'user list. Past sales and activity logs keep their name.',
      confirmText: 'Delete',
      icon: LucideIcons.trash2,
      isDangerous: true,
    );

    if (!confirmed) return;
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null || !mounted) return;

    final ok = await context.runWithWaiting(
      () => ref.read(userOperationsProvider.notifier).deleteUser(
            actor: currentUser,
            user: user,
          ),
      message: 'Deleting…',
    );

    if (!mounted) return;
    if (ok) {
      context.showSuccessSnackBar('${user.displayName} deleted');
    } else {
      final error = ref.read(userOperationsProvider).errorMessage;
      context.showErrorSnackBar(error ?? 'Failed to delete user');
    }
  }
```

- [ ] Run: `flutter test test/presentation/mobile/screens/users/users_screen_delete_test.dart` — **expected: 2 tests pass.**
- [ ] Run: `flutter analyze` — expected clean.
- [ ] Commit:

```bash
git add lib/presentation/mobile/widgets/users/user_list_tile.dart lib/presentation/mobile/screens/users/users_screen.dart test/presentation/mobile/screens/users/users_screen_delete_test.dart
git commit -m "feat(mobile): delete action for inactive users in user management

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Mobile — own-doc `accountStatusProvider`

**Files:**
- Create: `lib/presentation/providers/account_deactivation_provider.dart` (this task adds the enum + stream provider; Task 5 appends the controller to the same file)
- Modify: `lib/presentation/providers/providers.dart` (barrel export)
- Test: `test/presentation/providers/account_status_provider_test.dart` (create)

**Interfaces:**
- Consumes: `userRepositoryProvider`, `UserRepository.watchUser(String) → Stream<UserEntity?>` (maps `exists == false` → null), `authGatedStream(ref, build)` from `auth_provider.dart`, `currentUserProvider`.
- Produces: `enum AccountStatus { active, deactivated, deleted }`; `final accountStatusProvider = StreamProvider<AccountStatus>` (emits nothing while signed out; permission-denied stream error → `deleted`).

**Steps:**

- [ ] Write the failing test at `test/presentation/providers/account_status_provider_test.dart`:

```dart
import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/user_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/account_deactivation_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/user_provider.dart';

class _MockUserRepository extends Mock implements UserRepository {}

UserEntity _admin({bool isActive = true}) => UserEntity(
      id: 'u1',
      email: 'a@x.com',
      displayName: 'Admin',
      role: UserRole.admin,
      isActive: isActive,
      createdAt: DateTime(2026, 7, 1),
    );

void main() {
  test('maps own-doc snapshots to active/deactivated/deleted', () async {
    final repo = _MockUserRepository();
    final docs = StreamController<UserEntity?>();
    when(() => repo.watchUser('u1')).thenAnswer((_) => docs.stream);

    final container = ProviderContainer(overrides: [
      userRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
    ]);
    addTearDown(container.dispose);
    addTearDown(docs.close);

    final statuses = <AccountStatus>[];
    container.listen<AsyncValue<AccountStatus>>(accountStatusProvider,
        (_, next) {
      final value = next.valueOrNull;
      if (value != null) statuses.add(value);
    });

    await Future<void>.delayed(Duration.zero); // let authGatedStream subscribe
    docs.add(_admin());
    await Future<void>.delayed(Duration.zero);
    docs.add(_admin(isActive: false));
    await Future<void>.delayed(Duration.zero);
    docs.add(null); // doc gone
    await Future<void>.delayed(Duration.zero);

    expect(statuses, [
      AccountStatus.active,
      AccountStatus.deactivated,
      AccountStatus.deleted,
    ]);
  });

  test('permission-denied stream error surfaces as deleted', () async {
    final repo = _MockUserRepository();
    final docs = StreamController<UserEntity?>();
    when(() => repo.watchUser('u1')).thenAnswer((_) => docs.stream);

    final container = ProviderContainer(overrides: [
      userRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
    ]);
    addTearDown(container.dispose);
    addTearDown(docs.close);

    final statuses = <AccountStatus>[];
    container.listen<AsyncValue<AccountStatus>>(accountStatusProvider,
        (_, next) {
      final value = next.valueOrNull;
      if (value != null) statuses.add(value);
    });

    await Future<void>.delayed(Duration.zero);
    docs.addError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(statuses, [AccountStatus.deleted]);
  });

  test('emits nothing while signed out', () async {
    final repo = _MockUserRepository();

    final container = ProviderContainer(overrides: [
      userRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWith((ref) => Stream.value(null)),
    ]);
    addTearDown(container.dispose);

    final statuses = <AccountStatus>[];
    container.listen<AsyncValue<AccountStatus>>(accountStatusProvider,
        (_, next) {
      final value = next.valueOrNull;
      if (value != null) statuses.add(value);
    });

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(statuses, isEmpty);
    verifyNever(() => repo.watchUser(any()));
  });
}
```

- [ ] Run: `flutter test test/presentation/providers/account_status_provider_test.dart` — **expected failure:** compile error, `account_deactivation_provider.dart` does not exist.

- [ ] Create `lib/presentation/providers/account_deactivation_provider.dart`:

```dart
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
```

  (The `equatable` import is unused until Task 5 adds the state class to this same file — if `flutter analyze` flags it in this task, drop it here and re-add it in Task 5.)

- [ ] Add to `lib/presentation/providers/providers.dart` (alphabetical position is not enforced; append after the session_reset export):

```dart
export 'account_deactivation_provider.dart';
```

- [ ] Run: `flutter test test/presentation/providers/account_status_provider_test.dart` — **expected: 3 tests pass.**
- [ ] Run: `flutter analyze` — expected clean.
- [ ] Commit:

```bash
git add lib/presentation/providers/account_deactivation_provider.dart lib/presentation/providers/providers.dart test/presentation/providers/account_status_provider_test.dart
git commit -m "feat(mobile): live own-user account status stream

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Mobile — deactivation controller, blocking overlay, root wiring

**Files:**
- Modify: `lib/presentation/providers/account_deactivation_provider.dart` (append state + controller)
- Create: `lib/presentation/shared/widgets/common/account_deactivation_overlay.dart`
- Modify: `lib/app_mobile.dart`
- Test: `test/presentation/providers/account_deactivation_controller_test.dart` (create)
- Test: `test/presentation/shared/widgets/common/account_deactivation_overlay_test.dart` (create)

**Interfaces:**
- Consumes: `accountStatusProvider` (Task 4), `currentUserProvider`, `authActionsProvider` (`AuthNotifier.signOut()`), `authRepositoryProvider` (`AuthRepository.signOut()` fallback).
- Produces: `const accountDeactivationCountdownSeconds = 10;`; `class AccountDeactivationState extends Equatable { bool visible; int? secondsLeft; }` with `.hidden()` / `.countdown(int)` / `.immediate()`; `class AccountDeactivationController extends StateNotifier<AccountDeactivationState>` with `onDeactivated()`, `onDeleted()`, `reset()`; `accountDeactivationControllerProvider` (StateNotifierProvider that wires the listeners); `AccountDeactivationOverlay({required Widget child})` widget.

**Steps:**

- [ ] Write the failing controller test at `test/presentation/providers/account_deactivation_controller_test.dart`. Timer control uses `testWidgets` + `tester.pump(duration)` (fake-async zone), matching how this repo avoids real timers in tests:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/auth_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/account_deactivation_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';

class _MockAuthNotifier extends Mock implements AuthNotifier {}

class _MockAuthRepository extends Mock implements AuthRepository {}

UserEntity _admin() => UserEntity(
      id: 'u1',
      email: 'a@x.com',
      displayName: 'Admin',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2026, 7, 1),
    );

void main() {
  late _MockAuthNotifier auth;

  setUp(() {
    auth = _MockAuthNotifier();
    when(() => auth.signOut()).thenAnswer((_) async {});
  });

  ProviderContainer makeContainer({
    Stream<AccountStatus>? statusStream,
    Stream<UserEntity?>? authStream,
    AuthRepository? authRepo,
  }) {
    final container = ProviderContainer(overrides: [
      accountStatusProvider
          .overrideWith((ref) => statusStream ?? const Stream.empty()),
      currentUserProvider
          .overrideWith((ref) => authStream ?? Stream.value(_admin())),
      authActionsProvider.overrideWithValue(auth),
      if (authRepo != null) authRepositoryProvider.overrideWithValue(authRepo),
    ]);
    // Activate the controller (and with it the ref.listen wiring).
    container.listen(accountDeactivationControllerProvider, (_, __) {});
    return container;
  }

  testWidgets('deactivation event starts a 10s countdown, then signs out',
      (tester) async {
    final status = StreamController<AccountStatus>();
    final container = makeContainer(statusStream: status.stream);
    addTearDown(container.dispose);
    addTearDown(status.close);
    await tester.pump();

    status.add(AccountStatus.deactivated);
    await tester.pump();
    expect(
      container.read(accountDeactivationControllerProvider),
      const AccountDeactivationState.countdown(10),
    );

    await tester.pump(const Duration(seconds: 3));
    expect(
      container.read(accountDeactivationControllerProvider),
      const AccountDeactivationState.countdown(7),
    );
    verifyNever(() => auth.signOut());

    await tester.pump(const Duration(seconds: 7));
    expect(
      container.read(accountDeactivationControllerProvider),
      const AccountDeactivationState.countdown(0),
    );
    verify(() => auth.signOut()).called(1);
  });

  testWidgets('repeat deactivation events do not restart the countdown',
      (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pump();
    final controller =
        container.read(accountDeactivationControllerProvider.notifier);

    controller.onDeactivated();
    await tester.pump(const Duration(seconds: 3)); // 7 left
    controller.onDeactivated(); // stream noise
    await tester.pump(const Duration(seconds: 1));

    expect(
      container.read(accountDeactivationControllerProvider),
      const AccountDeactivationState.countdown(6),
    );
  });

  testWidgets('doc-gone signs out immediately, no countdown', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pump();

    container
        .read(accountDeactivationControllerProvider.notifier)
        .onDeleted();
    await tester.pump();

    expect(
      container.read(accountDeactivationControllerProvider),
      const AccountDeactivationState.immediate(),
    );
    verify(() => auth.signOut()).called(1);
  });

  testWidgets('doc-gone during a countdown escalates without double sign-out',
      (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pump();
    final controller =
        container.read(accountDeactivationControllerProvider.notifier);

    controller.onDeactivated();
    await tester.pump(const Duration(seconds: 2));
    controller.onDeleted();
    await tester.pump();
    verify(() => auth.signOut()).called(1);

    await tester.pump(const Duration(seconds: 20)); // stale timer must be dead
    verifyNever(() => auth.signOut());
  });

  testWidgets('normal sign-out resets the controller and cancels the timer',
      (tester) async {
    final authCtrl = StreamController<UserEntity?>();
    final container = makeContainer(authStream: authCtrl.stream);
    addTearDown(container.dispose);
    addTearDown(authCtrl.close);

    authCtrl.add(_admin()); // signed in
    await tester.pump();
    container
        .read(accountDeactivationControllerProvider.notifier)
        .onDeactivated();
    await tester.pump(const Duration(seconds: 2));

    authCtrl.add(null); // user signs out normally mid-countdown
    await tester.pump();

    expect(
      container.read(accountDeactivationControllerProvider),
      const AccountDeactivationState.hidden(),
    );
    await tester.pump(const Duration(seconds: 20));
    verifyNever(() => auth.signOut());
  });

  testWidgets('falls back to the raw repo sign-out if the use case throws',
      (tester) async {
    when(() => auth.signOut()).thenAnswer(
      (_) async => throw const AuthException(message: 'log write denied'),
    );
    final repo = _MockAuthRepository();
    when(() => repo.signOut()).thenAnswer((_) async {});
    final container = makeContainer(authRepo: repo);
    addTearDown(container.dispose);
    await tester.pump();

    container
        .read(accountDeactivationControllerProvider.notifier)
        .onDeleted();
    await tester.pump();

    verify(() => repo.signOut()).called(1);
  });
}
```

  Assumption: `AuthException` has a const constructor with a named `message` (it is constructed as `AuthException(message: ..., code: ...)` in `auth_provider.dart`; if it is not const, drop the `const`).

- [ ] Write the failing overlay test at `test/presentation/shared/widgets/common/account_deactivation_overlay_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/account_deactivation_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/account_deactivation_overlay.dart';

class _MockAuthNotifier extends Mock implements AuthNotifier {}

UserEntity _admin() => UserEntity(
      id: 'u1',
      email: 'a@x.com',
      displayName: 'Admin',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2026, 7, 1),
    );

void main() {
  late _MockAuthNotifier auth;

  setUp(() {
    auth = _MockAuthNotifier();
    when(() => auth.signOut()).thenAnswer((_) async {});
  });

  Future<void> pumpOverlay(WidgetTester tester, AccountStatus status) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        accountStatusProvider.overrideWith((ref) => Stream.value(status)),
        currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
        authActionsProvider.overrideWithValue(auth),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const AccountDeactivationOverlay(
          child: Scaffold(body: Text('behind')),
        ),
      ),
    ));
    await tester.pump(); // deliver the stream event
    await tester.pump(); // rebuild with the new controller state
  }

  testWidgets('shows the blocking modal with the binding copy + countdown',
      (tester) async {
    await pumpOverlay(tester, AccountStatus.deactivated);

    expect(find.text('Account deactivated'), findsOneWidget);
    expect(
      find.text('Your account has been deactivated by an administrator. '
          'You will be signed out.'),
      findsOneWidget,
    );
    expect(find.text('Signing out in 10s…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Signing out in 9s…'), findsOneWidget);

    // Drain the countdown so no timer leaks out of the test.
    await tester.pump(const Duration(seconds: 9));
    verify(() => auth.signOut()).called(1);
  });

  testWidgets('doc-gone shows the modal without a countdown and signs out',
      (tester) async {
    await pumpOverlay(tester, AccountStatus.deleted);

    expect(find.text('Account deactivated'), findsOneWidget);
    expect(find.text('Signing out…'), findsOneWidget);
    expect(find.textContaining('Signing out in'), findsNothing);
    verify(() => auth.signOut()).called(1);
  });

  testWidgets('renders nothing extra while the account stays active',
      (tester) async {
    await pumpOverlay(tester, AccountStatus.active);

    expect(find.text('behind'), findsOneWidget);
    expect(find.text('Account deactivated'), findsNothing);
    verifyNever(() => auth.signOut());
  });
}
```

- [ ] Run: `flutter test test/presentation/providers/account_deactivation_controller_test.dart test/presentation/shared/widgets/common/account_deactivation_overlay_test.dart` — **expected failure:** compile errors (`AccountDeactivationState`, `accountDeactivationControllerProvider`, `AccountDeactivationOverlay` do not exist).

- [ ] Implement: append to `lib/presentation/providers/account_deactivation_provider.dart`:

```dart
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

  /// isActive flipped false → show the modal with a 10s countdown, then sign
  /// out. Idempotent: repeated stream emissions never restart the countdown.
  void onDeactivated() {
    if (_fired) return;
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
    _fired = true;
    _timer?.cancel();
    state = const AccountDeactivationState.immediate();
    _doSignOut();
  }

  /// Any sign-out transition (ours or a normal one) tears everything down.
  void reset() {
    _timer?.cancel();
    _timer = null;
    _fired = false;
    _signedOut = false;
    state = const AccountDeactivationState.hidden();
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
    }
  });

  return controller;
});
```

- [ ] Create `lib/presentation/shared/widgets/common/account_deactivation_overlay.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/account_deactivation_provider.dart';

/// Root-level blocking overlay for mid-session deactivation/deletion.
///
/// Mounted from the MaterialApp.router `builder` slot (above the router's
/// Navigator), so it covers every screen and can't be dismissed or navigated
/// away from. Watching the controller here also activates the whole watcher
/// chain (accountStatusProvider → controller) for the app's lifetime.
class AccountDeactivationOverlay extends ConsumerWidget {
  const AccountDeactivationOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountDeactivationControllerProvider);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        child,
        if (state.visible) ...[
          ModalBarrier(
            dismissible: false,
            color: dark ? const Color(0x99000000) : const Color(0x52111C1D),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Material(
                color: dark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            LucideIcons.userX,
                            size: 22,
                            color: dark ? AppColors.errorOnDark : AppColors.error,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Account deactivated',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your account has been deactivated by an '
                        'administrator. You will be signed out.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontSize: 14.5, height: 1.55),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.secondsLeft != null
                            ? 'Signing out in ${state.secondsLeft}s…'
                            : 'Signing out…',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
```

  Note on string literals: the widget's body text and the tests' expected text are both written as two adjacent literals joined with a single space (`'…administrator. ' 'You will be signed out.'` vs `'…administrator. '\n'You will be signed out.'`) — they must concatenate to exactly `Your account has been deactivated by an administrator. You will be signed out.` Verify by running the test.

- [ ] Wire the overlay in `lib/app_mobile.dart`: add the import and wrap the builder child:

```dart
import 'package:maki_mobile_pos/presentation/shared/widgets/common/account_deactivation_overlay.dart';
```

  and change the builder to:

```dart
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: AccountDeactivationOverlay(
            child: _OfflineBanner(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
```

- [ ] Run: `flutter test test/presentation/providers/account_deactivation_controller_test.dart test/presentation/shared/widgets/common/account_deactivation_overlay_test.dart` — **expected: 9 tests pass.**
- [ ] Run the full mobile suite + analyzer: `flutter test && flutter analyze` — expected: all green (the `app_mobile.dart` wiring is covered by analyze + the existing suite booting the widget tree; manual smoke happens at the end).
- [ ] Commit:

```bash
git add lib/presentation/providers/account_deactivation_provider.dart lib/presentation/shared/widgets/common/account_deactivation_overlay.dart lib/app_mobile.dart test/presentation/providers/account_deactivation_controller_test.dart test/presentation/shared/widgets/common/account_deactivation_overlay_test.dart
git commit -m "feat(mobile): mid-session deactivation modal + timed auto sign-out

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Web — repo `delete`, guard, `useDeleteUser` hook

All commands in Tasks 6–8 run inside `web_admin/`.

**Files:**
- Modify: `web_admin/src/domain/repositories/UserRepository.ts`
- Modify: `web_admin/src/data/repositories/FirestoreUserRepository.ts`
- Modify: `web_admin/src/application/use-cases/userGuards.ts`
- Modify: `web_admin/src/presentation/hooks/useUserMutations.ts`
- Test: `web_admin/src/application/use-cases/userGuards.test.ts` (create)

**Interfaces:**
- Consumes: `UserGuardError`, `useUserRepo()`, `useAuthStore`, `useMutation` (existing idioms in the same files).
- Produces: `delete(id: string): Promise<void>` on the `UserRepository` interface + Firestore impl (`deleteDoc`); `assertDeleteAllowed(actor: User, target: User): void`; `useDeleteUser(): UseMutationResult<void, Error, User>`.

**Steps:**

- [ ] Write the failing guard test at `web_admin/src/application/use-cases/userGuards.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities';
import { assertDeleteAllowed, UserGuardError } from './userGuards';

const user = (o: Partial<User> = {}): User => ({
  id: 'u1',
  email: 'a@shop.test',
  displayName: 'A',
  role: UserRole.cashier,
  isActive: true,
  phoneNumber: null,
  photoUrl: null,
  createdAt: new Date('2026-01-01'),
  updatedAt: null,
  createdBy: null,
  updatedBy: null,
  lastLoginAt: null,
  ...o,
});

describe('assertDeleteAllowed', () => {
  it('throws self-delete when the target is the actor', () => {
    const actor = user({ id: 'me', role: UserRole.admin });
    expect(() => assertDeleteAllowed(actor, user({ id: 'me', isActive: false })))
      .toThrowError(UserGuardError);
    try {
      assertDeleteAllowed(actor, user({ id: 'me', isActive: false }));
    } catch (e) {
      expect((e as UserGuardError).code).toBe('self-delete');
    }
  });

  it('throws active-target for an active user (deactivate-first)', () => {
    const actor = user({ id: 'me', role: UserRole.admin });
    try {
      assertDeleteAllowed(actor, user({ id: 'u2', isActive: true }));
      expect.unreachable('should have thrown');
    } catch (e) {
      expect(e).toBeInstanceOf(UserGuardError);
      expect((e as UserGuardError).code).toBe('active-target');
    }
  });

  it('passes for an inactive other user', () => {
    const actor = user({ id: 'me', role: UserRole.admin });
    expect(() =>
      assertDeleteAllowed(actor, user({ id: 'u2', isActive: false })),
    ).not.toThrow();
  });
});
```

- [ ] Run: `npm run test -- src/application/use-cases/userGuards.test.ts` — **expected failure:** `assertDeleteAllowed` is not exported.

- [ ] Implement. In `web_admin/src/application/use-cases/userGuards.ts`, append:

```ts
export function assertDeleteAllowed(actor: User, target: User): void {
  if (target.id === actor.id) {
    throw new UserGuardError('You cannot delete yourself.', 'self-delete');
  }
  if (target.isActive) {
    throw new UserGuardError(
      'Deactivate this user before deleting them.',
      'active-target',
    );
  }
}
```

- [ ] In `web_admin/src/domain/repositories/UserRepository.ts`, add to the `UserRepository` interface (after `recordLogin`):

```ts
  // Removes the users/{uid} Firestore doc only — the Auth credential is
  // cleaned up out-of-band (scripts/delete-auth-user.mjs). Deactivate-first
  // and no-self-delete are enforced by the guard + Firestore rules.
  delete(id: string): Promise<void>;
```

- [ ] In `web_admin/src/data/repositories/FirestoreUserRepository.ts`, add `deleteDoc` to the `firebase/firestore` import list, and add after `recordLogin`:

```ts
  async delete(id: string): Promise<void> {
    await deleteDoc(doc(this.db, FirestoreCollections.users, id));
  }
```

- [ ] In `web_admin/src/presentation/hooks/useUserMutations.ts`, extend the guards import:

```ts
import {
  assertDeactivateAllowed,
  assertDeleteAllowed,
  assertUpdateAllowed,
} from '@/application/use-cases/userGuards';
```

  and append:

```ts
export function useDeleteUser() {
  const repo = useUserRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<void, Error, User>({
    mutationFn: async (target) => {
      if (!actor) throw new Error('Not signed in');
      assertDeleteAllowed(actor, target);
      await repo.delete(target.id);
    },
  });
}
```

- [ ] Run: `npm run test -- src/application/use-cases/userGuards.test.ts` — **expected: 3 tests pass.** Then `npm run typecheck` — expected clean.
- [ ] Commit:

```bash
git add web_admin/src/domain/repositories/UserRepository.ts web_admin/src/data/repositories/FirestoreUserRepository.ts web_admin/src/application/use-cases/userGuards.ts web_admin/src/presentation/hooks/useUserMutations.ts web_admin/src/application/use-cases/userGuards.test.ts
git commit -m "feat(web): user delete repo method, guard, and mutation hook

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Web — UsersListPage delete row action

**Files:**
- Modify: `web_admin/src/presentation/features/users/UsersListPage.tsx`
- Test: `web_admin/src/presentation/features/users/UsersListPage.test.tsx` (create)

**Interfaces:**
- Consumes: `useDeleteUser()` (Task 6), existing `confirm` state pattern in `UsersTable`, `Dialog`, `RowMenu`.
- Produces: `confirm` state widened to `null | { user: User; mode: 'deactivate' | 'reactivate' | 'delete' }`; Delete menu item on inactive rows only (never on the self row — self rows have no menu at all); destructive confirm dialog naming the user.

**Steps:**

- [ ] Write the failing page test at `web_admin/src/presentation/features/users/UsersListPage.test.tsx`:

```tsx
import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities';
import { UsersListPage } from './UsersListPage';

const user = (o: Partial<User> = {}): User => ({
  id: 'u1',
  email: 'a@shop.test',
  displayName: 'A',
  role: UserRole.cashier,
  isActive: true,
  phoneNumber: null,
  photoUrl: null,
  createdAt: new Date('2026-01-01'),
  updatedAt: null,
  createdBy: null,
  updatedBy: null,
  lastLoginAt: null,
  ...o,
});

const me = user({ id: 'me', displayName: 'Admin', role: UserRole.admin });

function harness(opts?: { users?: User[]; del?: ReturnType<typeof vi.fn> }) {
  useAuthStore.setState({ user: me, status: 'signedIn' });
  const qc = new QueryClient({
    defaultOptions: { mutations: { retry: false } },
  });
  const userRepo = {
    watchAll: vi.fn((cb: (users: User[]) => void) => {
      cb(opts?.users ?? []);
      return () => {};
    }),
    delete: opts?.del ?? vi.fn(async () => {}),
    deactivate: vi.fn(async () => {}),
    reactivate: vi.fn(async () => {}),
    listByRole: vi.fn(async () => []),
  } as unknown as Container['userRepo'];
  render(
    <DiProvider override={{ userRepo }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter>
          <UsersListPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return { userRepo };
}

describe('UsersListPage — delete action', () => {
  it('shows Delete in the row menu only for inactive users, never for me', async () => {
    harness({
      users: [
        me,
        user({ id: 'u2', displayName: 'Active Cashier' }),
        user({ id: 'u3', displayName: 'Gone Staff', role: UserRole.staff, isActive: false }),
      ],
    });

    // Self row never gets a menu at all → 2 menus for 3 rows.
    const menus = screen.getAllByRole('button', { name: /more actions/i });
    expect(menus).toHaveLength(2);

    // Active row (sorted active-first: Active Cashier, Admin/me, Gone Staff).
    await userEvent.click(menus[0]);
    expect(screen.getByRole('button', { name: /deactivate/i })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /^delete$/i })).not.toBeInTheDocument();
    await userEvent.click(document.body); // close the menu

    // Inactive row.
    await userEvent.click(screen.getAllByRole('button', { name: /more actions/i })[1]);
    expect(screen.getByRole('button', { name: /reactivate/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /^delete$/i })).toBeInTheDocument();
  });

  it('confirming Delete calls the repo with the user id', async () => {
    const del = vi.fn(async () => {});
    harness({
      users: [me, user({ id: 'u3', displayName: 'Gone Staff', isActive: false })],
      del,
    });

    await userEvent.click(screen.getByRole('button', { name: /more actions/i }));
    await userEvent.click(screen.getByRole('button', { name: /^delete$/i }));

    // Destructive confirm dialog names the user.
    const dialog = screen.getByRole('dialog');
    expect(dialog).toHaveTextContent('Delete user');
    expect(dialog).toHaveTextContent('Gone Staff');

    // Menu is closed now, so the only Delete button is the confirm action.
    await userEvent.click(screen.getByRole('button', { name: /^delete$/i }));
    await waitFor(() => expect(del).toHaveBeenCalledWith('u3'));
  });
});
```

- [ ] Run: `npm run test -- src/presentation/features/users/UsersListPage.test.tsx` — **expected failure:** no Delete button found in the inactive row menu.

- [ ] Implement in `web_admin/src/presentation/features/users/UsersListPage.tsx`:
  1. Add `TrashIcon` to the heroicons import and `useDeleteUser` to the mutations import:

```tsx
import {
  EllipsisHorizontalIcon,
  EyeIcon,
  EyeSlashIcon,
  PencilIcon,
  PlusIcon,
  TrashIcon,
  UserIcon,
  UserMinusIcon,
  UserPlusIcon,
} from '@heroicons/react/24/outline';
import {
  useDeactivateUser,
  useDeleteUser,
  useReactivateUser,
} from '@/presentation/hooks/useUserMutations';
```

  2. Rework `UsersTable`:

```tsx
function UsersTable({ users, myId }: { users: User[]; myId: string }) {
  const deactivate = useDeactivateUser();
  const reactivate = useReactivateUser();
  const deleteUser = useDeleteUser();
  const [confirm, setConfirm] = useState<null | {
    user: User;
    mode: 'deactivate' | 'reactivate' | 'delete';
  }>(null);

  const pending =
    deactivate.isPending || reactivate.isPending || deleteUser.isPending;
  const mutationError = deactivate.error ?? reactivate.error ?? deleteUser.error;

  const onConfirm = async () => {
    if (!confirm) return;
    if (confirm.mode === 'deactivate') {
      await deactivate.mutateAsync(confirm.user);
    } else if (confirm.mode === 'reactivate') {
      await reactivate.mutateAsync(confirm.user);
    } else {
      await deleteUser.mutateAsync(confirm.user);
    }
    setConfirm(null);
  };

  const confirmLabel =
    confirm?.mode === 'deactivate'
      ? 'Deactivate'
      : confirm?.mode === 'delete'
        ? 'Delete'
        : 'Reactivate';

  return (
    <>
      <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
        <table className="w-full text-bodySmall">
          <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
            <tr>
              <Th>User</Th>
              <Th>Role</Th>
              <Th>Last sign-in</Th>
              <Th>Status</Th>
              <Th className="text-right">Actions</Th>
            </tr>
          </thead>
          <tbody className="divide-y divide-light-hairline">
            {users.map((user) => (
              <UserRow
                key={user.id}
                user={user}
                isMe={user.id === myId}
                onDeactivate={() => setConfirm({ user, mode: 'deactivate' })}
                onReactivate={() => setConfirm({ user, mode: 'reactivate' })}
                onDelete={() => setConfirm({ user, mode: 'delete' })}
              />
            ))}
          </tbody>
        </table>
      </div>

      <Dialog
        open={confirm !== null}
        onClose={() => {
          if (pending) return;
          setConfirm(null);
          deactivate.reset();
          reactivate.reset();
          deleteUser.reset();
        }}
        title={
          confirm?.mode === 'deactivate'
            ? 'Deactivate user'
            : confirm?.mode === 'delete'
              ? 'Delete user'
              : 'Reactivate user'
        }
        description={
          confirm
            ? confirm.mode === 'deactivate'
              ? `${confirm.user.displayName || confirm.user.email} will no longer be able to sign in.`
              : confirm.mode === 'delete'
                ? `${confirm.user.displayName || confirm.user.email} will be permanently deleted. Past sales and activity logs keep their name.`
                : `${confirm.user.displayName || confirm.user.email} will be able to sign in again.`
            : undefined
        }
        dismissable={!pending}
      >
        {mutationError ? (
          <p className="mb-tk-md text-bodySmall text-error">
            {mutationError.message}
          </p>
        ) : null}
        <div className="flex justify-end gap-tk-sm">
          <button
            type="button"
            onClick={() => setConfirm(null)}
            disabled={pending}
            className="rounded-md px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-60"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={onConfirm}
            disabled={pending}
            className={cn(
              'flex items-center gap-tk-xs rounded-md px-tk-md py-tk-sm text-bodySmall font-semibold disabled:opacity-60',
              confirm?.mode === 'reactivate'
                ? 'bg-light-text text-light-background hover:bg-primary-dark'
                : 'bg-error text-white hover:bg-error-dark',
            )}
          >
            {pending ? <Spinner className="h-3.5 w-3.5" /> : null}
            {confirmLabel}
          </button>
        </div>
      </Dialog>
    </>
  );
}
```

  3. Thread `onDelete` through `UserRow` (add to props and pass to `RowMenu`):

```tsx
function UserRow({
  user,
  isMe,
  onDeactivate,
  onReactivate,
  onDelete,
}: {
  user: User;
  isMe: boolean;
  onDeactivate: () => void;
  onReactivate: () => void;
  onDelete: () => void;
}) {
```

  and in the `RowMenu` usage:

```tsx
                <RowMenu
                  user={user}
                  onClose={() => setMenuOpen(false)}
                  onDeactivate={() => {
                    setMenuOpen(false);
                    onDeactivate();
                  }}
                  onReactivate={() => {
                    setMenuOpen(false);
                    onReactivate();
                  }}
                  onDelete={() => {
                    setMenuOpen(false);
                    onDelete();
                  }}
                />
```

  4. Extend `RowMenu` — props gain `onDelete: () => void;` and the inactive branch renders Reactivate + Delete:

```tsx
      {user.isActive ? (
        <button
          type="button"
          onClick={onDeactivate}
          className="flex w-full items-center gap-tk-sm px-tk-md py-tk-sm text-left text-bodySmall text-error-dark hover:bg-error-light/40"
        >
          <UserMinusIcon className="h-4 w-4" />
          Deactivate
        </button>
      ) : (
        <>
          <button
            type="button"
            onClick={onReactivate}
            className="flex w-full items-center gap-tk-sm px-tk-md py-tk-sm text-left text-bodySmall text-light-text hover:bg-light-subtle"
          >
            <UserPlusIcon className="h-4 w-4" />
            Reactivate
          </button>
          <button
            type="button"
            onClick={onDelete}
            className="flex w-full items-center gap-tk-sm px-tk-md py-tk-sm text-left text-bodySmall text-error-dark hover:bg-error-light/40"
          >
            <TrashIcon className="h-4 w-4" />
            Delete
          </button>
        </>
      )}
```

- [ ] Run: `npm run test -- src/presentation/features/users/UsersListPage.test.tsx` — **expected: 2 tests pass.** Then `npm run typecheck` — expected clean.
- [ ] Commit:

```bash
git add web_admin/src/presentation/features/users/UsersListPage.tsx web_admin/src/presentation/features/users/UsersListPage.test.tsx
git commit -m "feat(web): delete action for inactive users on the users list

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Web — `AccountDeactivationGuard` (watcher + modal + auto sign-out)

**Files:**
- Modify: `web_admin/src/domain/repositories/UserRepository.ts` (optional `onError` on `watchOne`)
- Modify: `web_admin/src/data/repositories/FirestoreUserRepository.ts`
- Create: `web_admin/src/presentation/components/common/AccountDeactivationGuard.tsx`
- Modify: `web_admin/src/presentation/layouts/AdminShell.tsx`
- Test: `web_admin/src/presentation/components/common/AccountDeactivationGuard.test.tsx` (create)

**Interfaces:**
- Consumes: `useUserRepo()`, `useAuthRepo()` (`AuthRepository.signOut()`), `useAuthStore` (uid), `useNavigate`, `RoutePaths.login`, `Dialog` (with `dismissable={false}`).
- Produces: `watchOne(id, callback, onError?: (error: { code?: string; message?: string }) => void): Unsubscribe` (backward-compatible); `<AccountDeactivationGuard />` mounted in `AdminShell`.

**Steps:**

- [ ] Write the failing test at `web_admin/src/presentation/components/common/AccountDeactivationGuard.test.tsx`:

```tsx
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { act, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities';
import { AccountDeactivationGuard } from './AccountDeactivationGuard';

const user = (o: Partial<User> = {}): User => ({
  id: 'me',
  email: 'admin@shop.test',
  displayName: 'Admin',
  role: UserRole.admin,
  isActive: true,
  phoneNumber: null,
  photoUrl: null,
  createdAt: new Date('2026-01-01'),
  updatedAt: null,
  createdBy: null,
  updatedBy: null,
  lastLoginAt: null,
  ...o,
});

type SnapshotCb = (u: User | null) => void;
type ErrorCb = (e: { code?: string; message?: string }) => void;

function harness() {
  useAuthStore.setState({ user: user(), status: 'signedIn' });
  let snapshotCb: SnapshotCb | undefined;
  let errorCb: ErrorCb | undefined;
  const unsubscribe = vi.fn();
  const userRepo = {
    watchOne: vi.fn((_id: string, cb: SnapshotCb, onErr?: ErrorCb) => {
      snapshotCb = cb;
      errorCb = onErr;
      return unsubscribe;
    }),
  } as unknown as Container['userRepo'];
  const authRepo = {
    signOut: vi.fn(async () => {}),
  } as unknown as Container['authRepo'];

  const utils = render(
    <DiProvider override={{ userRepo, authRepo }}>
      <MemoryRouter>
        <AccountDeactivationGuard />
      </MemoryRouter>
    </DiProvider>,
  );

  return {
    snapshot: (u: User | null) => act(() => snapshotCb?.(u)),
    error: (e: { code?: string }) => act(() => errorCb?.(e)),
    authRepo,
    unsubscribe,
    ...utils,
  };
}

describe('AccountDeactivationGuard', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });
  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('renders nothing while the account stays active', () => {
    const h = harness();
    h.snapshot(user());
    expect(screen.queryByText('Account deactivated')).not.toBeInTheDocument();
    expect(h.authRepo.signOut).not.toHaveBeenCalled();
  });

  it('deactivation shows the modal copy and signs out after 10 seconds', async () => {
    const h = harness();
    h.snapshot(user({ isActive: false }));

    expect(screen.getByText('Account deactivated')).toBeInTheDocument();
    expect(
      screen.getByText(
        'Your account has been deactivated by an administrator. You will be signed out.',
      ),
    ).toBeInTheDocument();
    expect(screen.getByText(/10s/)).toBeInTheDocument();

    await act(async () => {
      vi.advanceTimersByTime(3000);
    });
    expect(screen.getByText(/7s/)).toBeInTheDocument();
    expect(h.authRepo.signOut).not.toHaveBeenCalled();

    await act(async () => {
      vi.advanceTimersByTime(7000);
      await Promise.resolve();
    });
    expect(h.authRepo.signOut).toHaveBeenCalledTimes(1);
  });

  it('repeat inactive snapshots do not restart the countdown', async () => {
    const h = harness();
    h.snapshot(user({ isActive: false }));
    await act(async () => {
      vi.advanceTimersByTime(3000);
    });
    h.snapshot(user({ isActive: false })); // snapshot noise
    await act(async () => {
      vi.advanceTimersByTime(1000);
    });
    expect(screen.getByText(/6s/)).toBeInTheDocument();
  });

  it('doc-gone signs out immediately with the modal, no countdown', async () => {
    const h = harness();
    h.snapshot(null);

    expect(screen.getByText('Account deactivated')).toBeInTheDocument();
    await act(async () => {
      await Promise.resolve();
    });
    expect(h.authRepo.signOut).toHaveBeenCalledTimes(1);
  });

  it('permission-denied stream error is treated like doc-gone', async () => {
    const h = harness();
    h.error({ code: 'permission-denied' });

    expect(screen.getByText('Account deactivated')).toBeInTheDocument();
    await act(async () => {
      await Promise.resolve();
    });
    expect(h.authRepo.signOut).toHaveBeenCalledTimes(1);
  });

  it('unmount (normal sign-out path) unsubscribes without showing the modal', () => {
    const h = harness();
    h.unmount();
    expect(h.unsubscribe).toHaveBeenCalledTimes(1);
    expect(h.authRepo.signOut).not.toHaveBeenCalled();
  });
});
```

- [ ] Run: `npm run test -- src/presentation/components/common/AccountDeactivationGuard.test.tsx` — **expected failure:** module `./AccountDeactivationGuard` does not exist.

- [ ] Implement. In `web_admin/src/domain/repositories/UserRepository.ts`, change the `watchOne` signature to:

```ts
  watchOne(
    id: string,
    callback: (user: User | null) => void,
    onError?: (error: { code?: string; message?: string }) => void,
  ): Unsubscribe;
```

- [ ] In `web_admin/src/data/repositories/FirestoreUserRepository.ts`, update the impl:

```ts
  watchOne(
    id: string,
    callback: (user: User | null) => void,
    onError?: (error: { code?: string; message?: string }) => void,
  ): Unsubscribe {
    return onSnapshot(
      doc(this.db, FirestoreCollections.users, id).withConverter(userConverter),
      (snap) => callback(snap.exists() ? snap.data() : null),
      (err) => onError?.(err),
    );
  }
```

  (`FirestoreError` from `onSnapshot`'s error callback has `code`/`message`, structurally compatible with the domain type — no firebase import leaks into the interface.)

- [ ] Create `web_admin/src/presentation/components/common/AccountDeactivationGuard.tsx`:

```tsx
// Watches the signed-in user's OWN users/{uid} doc for the whole signed-in
// session (this component lives in AdminShell, which is only mounted while
// signed in). Mid-session deactivation → blocking modal + 10s countdown →
// sign-out. Doc deleted (exists == false) or the stream erroring with
// permission-denied → same modal, immediate sign-out. Normal sign-out
// unmounts the shell, which tears the subscription + timer down without
// ever showing the modal.

import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthRepo, useUserRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { Dialog } from '@/presentation/components/common/Dialog';
import { RoutePaths } from '@/presentation/router/routePaths';

const COUNTDOWN_SECONDS = 10;

export function AccountDeactivationGuard() {
  const userRepo = useUserRepo();
  const authRepo = useAuthRepo();
  const navigate = useNavigate();
  const uid = useAuthStore((s) => s.user?.id ?? null);

  // null → all clear; countdown:true → deactivated (10s), false → doc gone.
  const [modal, setModal] = useState<null | { countdown: boolean }>(null);
  const [secondsLeft, setSecondsLeft] = useState(COUNTDOWN_SECONDS);

  // Own-doc subscription, alive for the whole signed-in session.
  useEffect(() => {
    if (!uid) return;
    let fired = false; // must not double-fire on repeated snapshots
    const unsubscribe = userRepo.watchOne(
      uid,
      (user) => {
        if (fired) return;
        if (user === null) {
          fired = true;
          setModal({ countdown: false });
        } else if (!user.isActive) {
          fired = true;
          setModal({ countdown: true });
        }
      },
      (error) => {
        if (fired) return;
        if (error.code === 'permission-denied') {
          fired = true;
          setModal({ countdown: false });
        }
      },
    );
    return () => {
      unsubscribe();
      setModal(null);
      setSecondsLeft(COUNTDOWN_SECONDS);
    };
  }, [uid, userRepo]);

  // Countdown → sign-out (or immediate sign-out for the doc-gone variant).
  useEffect(() => {
    if (!modal) return;
    const signOut = async () => {
      await authRepo.signOut().catch(() => {});
      navigate(RoutePaths.login, { replace: true });
    };
    if (!modal.countdown) {
      void signOut();
      return;
    }
    setSecondsLeft(COUNTDOWN_SECONDS);
    const interval = setInterval(() => {
      setSecondsLeft((s) => {
        if (s <= 1) {
          clearInterval(interval);
          void signOut();
          return 0;
        }
        return s - 1;
      });
    }, 1000);
    return () => clearInterval(interval);
  }, [modal, authRepo, navigate]);

  if (!modal) return null;

  return (
    <Dialog
      open
      onClose={() => {}}
      dismissable={false}
      title="Account deactivated"
      description="Your account has been deactivated by an administrator. You will be signed out."
    >
      <p className="text-bodySmall font-semibold text-light-text-secondary">
        {modal.countdown ? `Signing out in ${secondsLeft}s…` : 'Signing out…'}
      </p>
    </Dialog>
  );
}
```

- [ ] Mount it in `web_admin/src/presentation/layouts/AdminShell.tsx`:

```tsx
import { Outlet } from 'react-router-dom';
import { Sidebar } from '@/presentation/components/common/Sidebar';
import { OfflineBanner } from '@/presentation/components/common/OfflineBanner';
import { AccountDeactivationGuard } from '@/presentation/components/common/AccountDeactivationGuard';

export function AdminShell() {
  return (
    <div className="flex h-full w-full bg-light-background">
      <Sidebar />
      <main className="flex flex-1 flex-col overflow-hidden">
        <OfflineBanner />
        <div className="flex-1 overflow-auto">
          <Outlet />
        </div>
      </main>
      <AccountDeactivationGuard />
    </div>
  );
}
```

  (The `Dialog` portals to `document.body`, so placement inside the flex row is irrelevant.)

- [ ] Run: `npm run test -- src/presentation/components/common/AccountDeactivationGuard.test.tsx` — **expected: 6 tests pass.** Then the full web gate: `npm run typecheck && npm run test && npm run build` — expected clean.
- [ ] Commit:

```bash
git add web_admin/src/domain/repositories/UserRepository.ts web_admin/src/data/repositories/FirestoreUserRepository.ts web_admin/src/presentation/components/common/AccountDeactivationGuard.tsx web_admin/src/presentation/components/common/AccountDeactivationGuard.test.tsx web_admin/src/presentation/layouts/AdminShell.tsx
git commit -m "feat(web): mid-session deactivation modal + timed auto sign-out

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: Firestore rules — tighten users `allow delete` (+ rules tests)

A rules test rig **exists**: `tools/firestore-rules-test/` (`@firebase/rules-unit-testing` + mocha against the emulator, `npm test` wraps `firebase emulators:exec`; `node_modules` already installed). Extend it. **Do NOT deploy in this task** — rules deploy is gated on the user's explicit go-ahead (Task 10).

**Files:**
- Modify: `firestore.rules` (users block)
- Test: `tools/firestore-rules-test/test/rules.test.js` (modify)

**Interfaces:**
- Consumes: existing helpers `isAdmin()`, `isActiveUser()`; test harness `USERS` fixtures (`admin`, `staff`, `cashier`, `inactiveAdmin`, `inactiveStaff`), `as(key)`, `assertSucceeds`/`assertFails`.
- Produces: the exact rule from Global Constraints.

**Steps:**

- [ ] Write the failing rules tests: in `tools/firestore-rules-test/test/rules.test.js`, replace this existing block (currently ~lines 151–156, inside `describe("/users")`):

```js
  it("only admin can delete users", async () => {
    await assertFails(as("staff").collection("users").doc(USERS.cashier.uid).delete());
    await assertFails(as("cashier").collection("users").doc(USERS.staff.uid).delete());
    await assertSucceeds(as("admin").collection("users").doc(USERS.cashier.uid).delete());
  });
```

  with:

```js
  it("admin cannot delete an ACTIVE user (deactivate-first)", async () => {
    await assertFails(
      as("admin").collection("users").doc(USERS.cashier.uid).delete()
    );
  });

  it("admin cannot delete themselves", async () => {
    await assertFails(
      as("admin").collection("users").doc(USERS.admin.uid).delete()
    );
  });

  it("admin can delete an inactive other user", async () => {
    await assertSucceeds(
      as("admin").collection("users").doc(USERS.inactiveStaff.uid).delete()
    );
  });

  it("staff and cashier cannot delete users, even inactive ones", async () => {
    await assertFails(
      as("staff").collection("users").doc(USERS.inactiveStaff.uid).delete()
    );
    await assertFails(
      as("cashier").collection("users").doc(USERS.inactiveStaff.uid).delete()
    );
  });
```

  Leave the existing "inactive admin cannot delete users" test (~line 794) untouched — it still fails post-change (doubly: inactive actor AND active target).

- [ ] Run: `cd tools/firestore-rules-test && npm test` — **expected failure:** `admin cannot delete an ACTIVE user (deactivate-first)` fails (the current rule allows it). The other three new tests already pass. (The emulator needs Java; if it cannot start on this machine, note that and rely on the manual verification block below, but do not skip the rules edit.)

- [ ] Implement: in `firestore.rules`, replace the users-block line:

```
      allow delete: if isAdmin() && isActiveUser();
```

  with:

```
      // Delete is deactivate-first and never self: only an active admin may
      // delete ANOTHER user's doc, and only after that user is deactivated.
      // The Auth credential is removed separately (scripts/delete-auth-user.mjs).
      allow delete: if isAdmin() && isActiveUser()
        && request.auth.uid != userId
        && resource.data.isActive == false;
```

- [ ] Run: `cd tools/firestore-rules-test && npm test` — **expected: full suite passes** including the four new delete tests.
- [ ] Manual verification fallback (only if the emulator cannot run locally): after the user approves deploying rules (Task 10), verify in production with a throwaway inactive test user — (a) as admin, delete an inactive user → succeeds; (b) attempt delete of an active user via the web console network tab or a temporary code path → `permission-denied`; (c) confirm the admin's own doc cannot be deleted. Record the outcomes in the PR/summary.
- [ ] Commit:

```bash
git add firestore.rules tools/firestore-rules-test/test/rules.test.js
git commit -m "feat(rules): tighten users delete to inactive non-self targets

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 10: Auth-credential cleanup script + full verification + finish branch

**Files:**
- Create: `scripts/delete-auth-user.mjs`

**Interfaces:**
- Consumes: `firebase-admin/app` (`initializeApp`, `applicationDefault`), `firebase-admin/auth` (`getAuth().getUserByEmail` / `getUser` / `deleteUser`), `firebase-admin/firestore` (`getFirestore`), conventions from `scripts/backfill-product-barcodes.mjs` and the `--apply` gating from `scripts/rename-product-category.mjs`.
- Produces: `node delete-auth-user.mjs <email-or-uid> [--apply]`.

**Steps:**

- [ ] Create `scripts/delete-auth-user.mjs` (no unit test — it is pure side effect against live services, matching the other operational scripts; verification is `node --check` + a manual dry-run):

```js
// Deletes a Firebase AUTH credential for a user whose Firestore doc has
// already been deleted in-app. Client SDKs cannot remove another user's Auth
// account, so in-app "Delete user" removes only users/{uid}; this script
// closes the gap. It ABORTS if users/{uid} still exists — deactivate and
// delete the user in the app first.
//
// Run:
//   cd scripts && npm install
//   gcloud auth application-default login        # OR export GOOGLE_APPLICATION_CREDENTIALS=<sa.json>
//   node delete-auth-user.mjs <email-or-uid>           # dry-run: prints what it found
//   node delete-auth-user.mjs <email-or-uid> --apply   # actually deletes the credential
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const PROJECT_ID = 'maki-mobile-pos';

const [target, applyFlag] = process.argv.slice(2);
if (!target) {
  console.error('Usage: node delete-auth-user.mjs <email-or-uid> [--apply]');
  process.exit(1);
}
const apply = applyFlag === '--apply';

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const auth = getAuth();
const db = getFirestore();

function lookup(target) {
  return target.includes('@') ? auth.getUserByEmail(target) : auth.getUser(target);
}

async function main() {
  let user;
  try {
    user = await lookup(target);
  } catch (e) {
    console.error(`No auth account found for "${target}": ${e.message}`);
    process.exit(1);
  }

  console.log('Found auth account:');
  console.log(`  uid:       ${user.uid}`);
  console.log(`  email:     ${user.email ?? '(none)'}`);
  console.log(`  created:   ${user.metadata.creationTime}`);
  console.log(`  lastLogin: ${user.metadata.lastSignInTime ?? '(never)'}`);

  const docSnap = await db.collection('users').doc(user.uid).get();
  if (docSnap.exists) {
    console.error(
      `\nABORT: users/${user.uid} still exists ` +
        `(displayName: "${docSnap.get('displayName')}", isActive: ${docSnap.get('isActive')}).\n` +
        'Delete the user in the app first (deactivate, then delete), then re-run.'
    );
    process.exit(1);
  }
  console.log(`\nusers/${user.uid} does not exist — safe to delete the auth credential.`);

  if (!apply) {
    console.log('\nDry run only — re-run with --apply to delete the auth credential.');
    return;
  }

  await auth.deleteUser(user.uid);
  console.log(`\nDeleted auth credential for ${user.email ?? user.uid}.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
```

- [ ] Verify syntax: `node --check scripts/delete-auth-user.mjs` — expected: no output, exit 0.
- [ ] Commit:

```bash
git add scripts/delete-auth-user.mjs
git commit -m "feat(scripts): delete-auth-user credential cleanup script

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Full verification (all must pass — paste outputs, do not assert without running):**
  - Repo root: `flutter analyze` → 0 issues.
  - Repo root: `flutter test` → all pass (expect the pre-existing count ~1141 + the 23 new tests from Tasks 1–5).
  - `cd web_admin && npm run typecheck && npm run test && npm run build` → all pass (expect ~196 pre-existing + ~11 new).
  - `cd tools/firestore-rules-test && npm test` → all pass (or the documented emulator-unavailable note from Task 9).
- [ ] Run the repo's review step: invoke `/code-review` (superpowers:requesting-code-review) on the full branch diff (`git diff main...feat/user-deletion`); fix anything it finds and re-run the affected suites.
- [ ] Manual smoke (with the user, per spec Verification):
  - Deactivate a signed-in test user from the other surface → modal + 10s countdown + auto sign-out observed on **both** surfaces.
  - Delete flow end-to-end (deactivate → delete → user gone from both lists; active/self rows never offer delete).
  - Script: dry-run against a throwaway auth account (abort while doc exists; safe message after in-app delete), then `--apply`.
- [ ] Finish via superpowers:finishing-a-development-branch (merge to `main` or open a PR per the user's choice). **Deployment gates:**
  - `firebase deploy --only firestore:rules` — **production-affecting; NEEDS explicit user confirmation first** (CLAUDE.md rule). Deploy rules together with or before the web hosting deploy.
  - Web: `cd web_admin && npm run build`, then `firebase deploy --only hosting` — also confirm with the user.
  - Mobile: rides the next APK (`flutter build apk --release`, manual `adb install` per the release process note) — no action in this plan beyond noting it.
