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

    // Dispose before the test body returns (not just via addTearDown): the
    // countdown's periodic Timer is still live at this point, and
    // flutter_test's pending-timer invariant is checked immediately after
    // the test callback returns, before addTearDown callbacks run.
    container.dispose();
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
