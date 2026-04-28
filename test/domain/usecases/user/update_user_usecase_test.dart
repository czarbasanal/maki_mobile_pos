import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/user_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/user/update_user_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockActivityLogRepository extends Mock implements ActivityLogRepository {
}

class _FakeUser extends Fake implements UserEntity {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _user(
  UserRole role, {
  String? id,
  bool isActive = true,
  String displayName = '',
}) =>
    UserEntity(
      id: id ?? 'u-${role.value}',
      email: '${role.value}@test',
      displayName: displayName.isEmpty ? '${role.value} user' : displayName,
      role: role,
      isActive: isActive,
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUser());
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockUserRepository repo;
  late _MockActivityLogRepository logRepo;
  late UpdateUserUseCase useCase;

  setUp(() {
    repo = _MockUserRepository();
    logRepo = _MockActivityLogRepository();
    useCase = UpdateUserUseCase(
      repository: repo,
      logger: ActivityLogger(logRepo),
    );

    when(() => repo.updateUser(
          user: any(named: 'user'),
          updatedBy: any(named: 'updatedBy'),
        )).thenAnswer((inv) async => inv.namedArguments[#user] as UserEntity);
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  // ===================================================================
  // Permission tier
  // ===================================================================
  group('permission tier', () {
    test('admin can update any user', () async {
      final target = _user(UserRole.cashier, id: 'u-c1');
      when(() => repo.getUserById('u-c1')).thenAnswer((_) async => target);

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        user: target.copyWith(displayName: 'Renamed'),
      );

      expect(result.success, true);
      verify(() => repo.updateUser(
            user: any(named: 'user'),
            updatedBy: 'u-admin',
          )).called(1);
    });

    test('cashier can update their own non-role/non-active fields '
        '(editOwnProfile)', () async {
      final cashier = _user(UserRole.cashier);
      when(() => repo.getUserById('u-cashier'))
          .thenAnswer((_) async => cashier);

      final result = await useCase.execute(
        actor: cashier,
        user: cashier.copyWith(displayName: 'Renamed Self'),
      );

      expect(result.success, true);
    });

    test('cashier CANNOT update another user', () async {
      final target = _user(UserRole.staff, id: 'u-s1');
      when(() => repo.getUserById('u-s1')).thenAnswer((_) async => target);

      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        user: target.copyWith(displayName: 'Hacked'),
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
      verifyNever(() => repo.updateUser(
            user: any(named: 'user'),
            updatedBy: any(named: 'updatedBy'),
          ));
    });

    test('staff CANNOT update another user', () async {
      final target = _user(UserRole.cashier, id: 'u-c1');
      when(() => repo.getUserById('u-c1')).thenAnswer((_) async => target);

      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        user: target.copyWith(displayName: 'Renamed'),
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });

    test('inactive admin denied (isActive gate via assertPermission)', () async {
      final target = _user(UserRole.cashier, id: 'u-c1');
      when(() => repo.getUserById('u-c1')).thenAnswer((_) async => target);

      final result = await useCase.execute(
        actor: _user(UserRole.admin, isActive: false),
        user: target.copyWith(displayName: 'X'),
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });
  });

  // ===================================================================
  // Self-guards
  // ===================================================================
  group('self guards', () {
    test('admin CANNOT change their own role', () async {
      final admin = _user(UserRole.admin);
      when(() => repo.getUserById('u-admin')).thenAnswer((_) async => admin);

      final result = await useCase.execute(
        actor: admin,
        user: admin.copyWith(role: UserRole.cashier),
      );

      expect(result.success, false);
      expect(result.errorCode, 'self-role-change');
      verifyNever(() => repo.updateUser(
            user: any(named: 'user'),
            updatedBy: any(named: 'updatedBy'),
          ));
    });

    test('admin CANNOT deactivate themselves', () async {
      // Need at least 2 admins so we hit the self-deactivate guard before
      // the last-admin guard.
      final admin = _user(UserRole.admin);
      final otherAdmin = _user(UserRole.admin, id: 'u-admin-2');
      when(() => repo.getUserById('u-admin')).thenAnswer((_) async => admin);
      when(() => repo.getUsersByRole(UserRole.admin))
          .thenAnswer((_) async => [admin, otherAdmin]);

      final result = await useCase.execute(
        actor: admin,
        user: admin.copyWith(isActive: false),
      );

      expect(result.success, false);
      expect(result.errorCode, 'self-deactivate');
    });
  });

  // ===================================================================
  // Last-admin guard
  // ===================================================================
  group('last-admin guard', () {
    test('CANNOT demote the last active admin', () async {
      final lastAdmin = _user(UserRole.admin, id: 'u-last');
      // Actor is a *different* admin to bypass the self-role-change guard.
      final actor = _user(UserRole.admin, id: 'u-acting');
      when(() => repo.getUserById('u-last'))
          .thenAnswer((_) async => lastAdmin);
      when(() => repo.getUsersByRole(UserRole.admin))
          .thenAnswer((_) async => [lastAdmin]);

      final result = await useCase.execute(
        actor: actor,
        user: lastAdmin.copyWith(role: UserRole.cashier),
      );

      expect(result.success, false);
      expect(result.errorCode, 'last-admin');
    });

    test('CANNOT deactivate the last active admin', () async {
      final lastAdmin = _user(UserRole.admin, id: 'u-last');
      final actor = _user(UserRole.admin, id: 'u-acting');
      when(() => repo.getUserById('u-last'))
          .thenAnswer((_) async => lastAdmin);
      when(() => repo.getUsersByRole(UserRole.admin))
          .thenAnswer((_) async => [lastAdmin]);

      final result = await useCase.execute(
        actor: actor,
        user: lastAdmin.copyWith(isActive: false),
      );

      expect(result.success, false);
      expect(result.errorCode, 'last-admin');
    });

    test('CAN demote an admin when other active admins exist', () async {
      final target = _user(UserRole.admin, id: 'u-target');
      final otherAdmin = _user(UserRole.admin, id: 'u-other');
      final actor = _user(UserRole.admin, id: 'u-acting');
      when(() => repo.getUserById('u-target'))
          .thenAnswer((_) async => target);
      when(() => repo.getUsersByRole(UserRole.admin))
          .thenAnswer((_) async => [target, otherAdmin, actor]);

      final result = await useCase.execute(
        actor: actor,
        user: target.copyWith(role: UserRole.staff),
      );

      expect(result.success, true);
    });

    test('inactive admin in the list does not count toward the active count',
        () async {
      final target = _user(UserRole.admin, id: 'u-target');
      final inactiveOther = _user(UserRole.admin,
          id: 'u-inactive', isActive: false);
      final actor = _user(UserRole.admin, id: 'u-acting');
      when(() => repo.getUserById('u-target'))
          .thenAnswer((_) async => target);
      when(() => repo.getUsersByRole(UserRole.admin))
          .thenAnswer((_) async => [target, inactiveOther]);

      // Active admins: just `target` (the actor's session is admin but not in
      // the list returned by the repo for this test). Demoting target should
      // be blocked because it leaves zero active admins.
      final result = await useCase.execute(
        actor: actor,
        user: target.copyWith(role: UserRole.cashier),
      );

      expect(result.success, false);
      expect(result.errorCode, 'last-admin');
    });
  });

  // ===================================================================
  // Misc
  // ===================================================================
  group('misc', () {
    test('returns not-found if target user does not exist', () async {
      when(() => repo.getUserById('missing')).thenAnswer((_) async => null);

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        user: _user(UserRole.cashier, id: 'missing'),
      );

      expect(result.success, false);
      expect(result.errorCode, 'not-found');
    });

    test('writes a role-changed log entry when role changes', () async {
      final target = _user(UserRole.cashier, id: 'u-c1');
      final actor = _user(UserRole.admin);
      when(() => repo.getUserById('u-c1')).thenAnswer((_) async => target);

      await useCase.execute(
        actor: actor,
        user: target.copyWith(role: UserRole.staff),
      );

      // Two log writes: userUpdated + roleChanged
      verify(() => logRepo.logActivity(any())).called(2);
    });
  });
}
