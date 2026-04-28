import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/auth_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/auth/verify_password_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockActivityLogRepository extends Mock implements ActivityLogRepository {
}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _user() => UserEntity(
      id: 'u-1',
      email: 'admin@test',
      displayName: 'Admin',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockAuthRepository auth;
  late _MockActivityLogRepository logRepo;
  late VerifyPasswordUseCase useCase;

  setUp(() {
    auth = _MockAuthRepository();
    logRepo = _MockActivityLogRepository();
    useCase = VerifyPasswordUseCase(
      repository: auth,
      logger: ActivityLogger(logRepo),
    );

    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  group('VerifyPasswordUseCase', () {
    test('returns true on correct password and writes verified log', () async {
      when(() => auth.verifyPassword(any())).thenAnswer((_) async => true);

      final result = await useCase.execute(
        actor: _user(),
        password: 'admin123',
        purpose: 'void sale',
      );

      expect(result.success, true);
      expect(result.data, true);
      verify(() => logRepo.logActivity(any())).called(1);
    });

    test('returns false on wrong password and writes failed log', () async {
      when(() => auth.verifyPassword(any())).thenAnswer((_) async => false);

      final result = await useCase.execute(
        actor: _user(),
        password: 'wrong',
        purpose: 'view cost',
      );

      expect(result.success, true);
      expect(result.data, false);
      verify(() => logRepo.logActivity(any())).called(1);
    });

    test('repository exception surfaces as failure', () async {
      when(() => auth.verifyPassword(any())).thenThrow(Exception('Auth down'));

      final result = await useCase.execute(
        actor: _user(),
        password: 'x',
      );

      expect(result.success, false);
      expect(result.errorMessage, contains('Auth down'));
    });
  });
}
