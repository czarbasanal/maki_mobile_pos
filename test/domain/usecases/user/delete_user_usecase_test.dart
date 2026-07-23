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
