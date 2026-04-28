import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/auth_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/auth/sign_in_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockActivityLogRepository extends Mock implements ActivityLogRepository {
}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _user(UserRole role) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockAuthRepository auth;
  late _MockActivityLogRepository logRepo;
  late SignInUseCase useCase;

  setUp(() {
    auth = _MockAuthRepository();
    logRepo = _MockActivityLogRepository();
    useCase = SignInUseCase(repository: auth, logger: ActivityLogger(logRepo));

    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  group('SignInUseCase', () {
    test('successful sign-in returns user and writes login log', () async {
      when(() => auth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => _user(UserRole.cashier));

      final result = await useCase.execute(
        email: 'cashier@test',
        password: 'pw',
      );

      expect(result.success, true);
      expect(result.data?.role, UserRole.cashier);
      verify(() => logRepo.logActivity(any())).called(1);
    });

    test('invalid credentials surface as failure with code preserved', () async {
      when(() => auth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(const InvalidCredentialsException());

      final result = await useCase.execute(
        email: 'cashier@test',
        password: 'wrong',
      );

      expect(result.success, false);
      expect(result.errorCode, 'invalid-credentials');
      verifyNever(() => logRepo.logActivity(any()));
    });

    test('disabled account surfaces with account-disabled code', () async {
      when(() => auth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(const AccountDisabledException());

      final result = await useCase.execute(
        email: 'gone@test',
        password: 'pw',
      );

      expect(result.success, false);
      expect(result.errorCode, 'account-disabled');
    });

    test('unknown error wrapped in failure', () async {
      when(() => auth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(Exception('Network unreachable'));

      final result = await useCase.execute(
        email: 'x@test',
        password: 'pw',
      );

      expect(result.success, false);
      expect(result.errorMessage, contains('Network unreachable'));
    });
  });
}
