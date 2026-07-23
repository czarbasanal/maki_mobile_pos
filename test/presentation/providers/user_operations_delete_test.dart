import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/user_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/user_provider.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

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
