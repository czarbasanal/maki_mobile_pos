import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/petty_cash_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/petty_cash_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/petty_cash/perform_cutoff_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockPettyCashRepository extends Mock implements PettyCashRepository {}

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

PettyCashEntity _cutoffRecord({double balance = 1234.56}) => PettyCashEntity(
      id: 'cutoff-1',
      type: PettyCashType.cutOff,
      amount: balance,
      balance: 0,
      description: 'End of day',
      createdAt: DateTime(2025, 1, 1, 23, 59),
      createdBy: 'u-admin',
      createdByName: 'admin user',
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockPettyCashRepository repo;
  late _MockActivityLogRepository logRepo;
  late PerformCutOffUseCase useCase;

  setUp(() {
    repo = _MockPettyCashRepository();
    logRepo = _MockActivityLogRepository();
    useCase = PerformCutOffUseCase(
      repository: repo,
      logger: ActivityLogger(logRepo),
    );

    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  group('PerformCutOffUseCase', () {
    test('admin performs cut-off and records closing balance', () async {
      when(() => repo.getCurrentBalance()).thenAnswer((_) async => 1234.56);
      when(() => repo.performCutOff(
            createdBy: any(named: 'createdBy'),
            createdByName: any(named: 'createdByName'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) async => _cutoffRecord());

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        notes: 'Standard close',
      );

      expect(result.success, true);
      expect(result.data?.type, PettyCashType.cutOff);
      verify(() => repo.performCutOff(
            createdBy: 'u-admin',
            createdByName: 'admin user',
            notes: 'Standard close',
          )).called(1);
      verify(() => logRepo.logActivity(any())).called(1);
    });

    test('staff is denied (performCutOff is admin-only)', () async {
      final result = await useCase.execute(actor: _user(UserRole.staff));

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
      verifyNever(() => repo.performCutOff(
            createdBy: any(named: 'createdBy'),
            createdByName: any(named: 'createdByName'),
            notes: any(named: 'notes'),
          ));
    });

    test('cashier is denied', () async {
      final result = await useCase.execute(actor: _user(UserRole.cashier));

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });

    test('cut-off succeeds even when balance is zero', () async {
      when(() => repo.getCurrentBalance()).thenAnswer((_) async => 0);
      when(() => repo.performCutOff(
            createdBy: any(named: 'createdBy'),
            createdByName: any(named: 'createdByName'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) async => _cutoffRecord(balance: 0));

      final result = await useCase.execute(actor: _user(UserRole.admin));

      expect(result.success, true);
    });
  });
}
