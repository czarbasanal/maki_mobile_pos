import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/user_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/user/create_user_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockActivityLogRepository extends Mock implements ActivityLogRepository {
}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _user(UserRole role, {bool isActive = true}) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: isActive,
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
    registerFallbackValue(UserRole.cashier);
  });

  late _MockUserRepository repo;
  late _MockActivityLogRepository logRepo;
  late CreateUserUseCase useCase;

  setUp(() {
    repo = _MockUserRepository();
    logRepo = _MockActivityLogRepository();
    useCase = CreateUserUseCase(
      repository: repo,
      logger: ActivityLogger(logRepo),
    );

    when(() => repo.createUser(
          email: any(named: 'email'),
          password: any(named: 'password'),
          displayName: any(named: 'displayName'),
          role: any(named: 'role'),
          createdBy: any(named: 'createdBy'),
        )).thenAnswer((inv) async => UserEntity(
          id: 'u-new',
          email: inv.namedArguments[#email] as String,
          displayName: inv.namedArguments[#displayName] as String,
          role: inv.namedArguments[#role] as UserRole,
          isActive: true,
          createdAt: DateTime(2025, 1, 1),
        ));
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  group('CreateUserUseCase', () {
    test('admin creates user successfully', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        email: 'new@test',
        password: 'secret123',
        displayName: 'New Hire',
        role: UserRole.cashier,
      );

      expect(result.success, true);
      expect(result.data?.id, 'u-new');
      verify(() => repo.createUser(
            email: 'new@test',
            password: 'secret123',
            displayName: 'New Hire',
            role: UserRole.cashier,
            createdBy: 'u-admin',
          )).called(1);
      verify(() => logRepo.logActivity(any())).called(1);
    });

    test('cashier denied (addUser is admin-only)', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        email: 'x@test',
        password: 'pw',
        displayName: 'X',
        role: UserRole.cashier,
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
      verifyNever(() => repo.createUser(
            email: any(named: 'email'),
            password: any(named: 'password'),
            displayName: any(named: 'displayName'),
            role: any(named: 'role'),
            createdBy: any(named: 'createdBy'),
          ));
    });

    test('staff denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        email: 'x@test',
        password: 'pw',
        displayName: 'X',
        role: UserRole.cashier,
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });

    test('inactive admin denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin, isActive: false),
        email: 'x@test',
        password: 'pw',
        displayName: 'X',
        role: UserRole.cashier,
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });

    test('repository failure surfaces as failed UseCaseResult', () async {
      when(() => repo.createUser(
            email: any(named: 'email'),
            password: any(named: 'password'),
            displayName: any(named: 'displayName'),
            role: any(named: 'role'),
            createdBy: any(named: 'createdBy'),
          )).thenThrow(Exception('Email already in use'));

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        email: 'dup@test',
        password: 'pw',
        displayName: 'Dup',
        role: UserRole.cashier,
      );

      expect(result.success, false);
      expect(result.errorMessage, contains('Email already in use'));
    });
  });
}
