import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/auth_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/auth/sign_out_usecase.dart';
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
  late SignOutUseCase useCase;

  setUp(() {
    auth = _MockAuthRepository();
    logRepo = _MockActivityLogRepository();
    useCase = SignOutUseCase(repository: auth, logger: ActivityLogger(logRepo));

    when(() => auth.signOut()).thenAnswer((_) async {});
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  group('SignOutUseCase', () {
    test('logs logout when actor is provided', () async {
      final result = await useCase.execute(actor: _user());

      expect(result.success, true);
      verify(() => logRepo.logActivity(any())).called(1);
      verify(() => auth.signOut()).called(1);
    });

    test('skips log when actor is null (already-unauthenticated case)',
        () async {
      final result = await useCase.execute(actor: null);

      expect(result.success, true);
      verifyNever(() => logRepo.logActivity(any()));
      verify(() => auth.signOut()).called(1);
    });

    test('repository failure surfaces as failed UseCaseResult', () async {
      when(() => auth.signOut()).thenThrow(Exception('Network down'));

      final result = await useCase.execute(actor: _user());

      expect(result.success, false);
      expect(result.errorMessage, contains('Network down'));
    });
  });
}
