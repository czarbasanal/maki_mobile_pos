import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/user_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/user_provider.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// Regression: editing the signed-in user's profile (e.g. display name) from
/// Settings must refresh [currentUserProvider] so the dashboard — which reads
/// its name off that provider — reflects the change without an app restart.
///
/// [currentUserProvider] is fed by FirebaseAuth.authStateChanges, which does
/// NOT re-emit on a Firestore profile edit, so the operations notifier has to
/// invalidate it explicitly — but only when the edited user is the signed-in
/// user (editing someone else must not disturb the current-user stream).
class _MockUserRepository extends Mock implements UserRepository {}

class _MockActivityLogRepository extends Mock
    implements ActivityLogRepository {}

class _FakeUser extends Fake implements UserEntity {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUser());
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockUserRepository repo;
  late _MockActivityLogRepository logRepo;

  UserEntity admin() => UserEntity(
        id: 'u1',
        email: 'a@x.com',
        displayName: 'Old Name',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );

  setUp(() {
    repo = _MockUserRepository();
    logRepo = _MockActivityLogRepository();
    when(() => repo.updateUser(
          user: any(named: 'user'),
          updatedBy: any(named: 'updatedBy'),
        )).thenAnswer((inv) async => inv.namedArguments[#user] as UserEntity);
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  ProviderContainer makeContainer(void Function() onCurrentUserBuild) {
    return ProviderContainer(overrides: [
      userRepositoryProvider.overrideWithValue(repo),
      activityLogRepositoryProvider.overrideWithValue(logRepo),
      currentUserProvider.overrideWith((ref) {
        onCurrentUserBuild();
        return Stream.value(admin());
      }),
    ]);
  }

  test('editing the signed-in user refreshes currentUserProvider', () async {
    when(() => repo.getUserById('u1')).thenAnswer((_) async => admin());

    var currentUserBuilds = 0;
    final container = makeContainer(() => currentUserBuilds++);
    addTearDown(container.dispose);
    final sub = container.listen(currentUserProvider, (_, __) {});
    addTearDown(sub.close);
    await container.read(currentUserProvider.future); // warm the stream

    final buildsBefore = currentUserBuilds;
    final ops = container.read(userOperationsProvider.notifier);
    final updated = await ops.updateUser(
      actor: admin(),
      user: admin().copyWith(displayName: 'New Name'),
    );
    expect(updated, isNotNull);

    await Future<void>.delayed(Duration.zero);
    container.read(currentUserProvider); // flush any pending recompute

    expect(
      currentUserBuilds,
      greaterThan(buildsBefore),
      reason: 'currentUserProvider should be invalidated so the dashboard '
          'reflects the new display name',
    );
  });

  test('editing a different user does NOT refresh currentUserProvider',
      () async {
    final other = UserEntity(
      id: 'u2',
      email: 'b@x.com',
      displayName: 'Cashier',
      role: UserRole.cashier,
      isActive: true,
      createdAt: DateTime(2026, 6, 1),
    );
    when(() => repo.getUserById('u2')).thenAnswer((_) async => other);

    var currentUserBuilds = 0;
    final container = makeContainer(() => currentUserBuilds++);
    addTearDown(container.dispose);
    final sub = container.listen(currentUserProvider, (_, __) {});
    addTearDown(sub.close);
    await container.read(currentUserProvider.future);

    final buildsBefore = currentUserBuilds;
    final ops = container.read(userOperationsProvider.notifier);
    final updated = await ops.updateUser(
      actor: admin(),
      user: other.copyWith(displayName: 'Cashier Renamed'),
    );
    expect(updated, isNotNull);

    await Future<void>.delayed(Duration.zero);
    container.read(currentUserProvider);

    expect(
      currentUserBuilds,
      buildsBefore,
      reason: 'editing another user must not disturb the current-user stream',
    );
  });
}
