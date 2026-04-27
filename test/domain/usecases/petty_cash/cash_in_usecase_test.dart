import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/petty_cash_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/petty_cash_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/petty_cash/cash_in_usecase.dart';
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

PettyCashEntity _record({
  String id = 'rec-1',
  double amount = 100,
  double balance = 1100,
}) =>
    PettyCashEntity(
      id: id,
      type: PettyCashType.cashIn,
      amount: amount,
      balance: balance,
      description: 'Top-up',
      createdAt: DateTime(2025, 1, 1, 9),
      createdBy: 'u-admin',
      createdByName: 'admin user',
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockPettyCashRepository repo;
  late _MockActivityLogRepository logRepo;
  late CashInUseCase useCase;

  setUp(() {
    repo = _MockPettyCashRepository();
    logRepo = _MockActivityLogRepository();
    useCase = CashInUseCase(
      repository: repo,
      logger: ActivityLogger(logRepo),
    );

    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  group('CashInUseCase', () {
    test('admin records cash in successfully', () async {
      final created = _record(amount: 500);
      when(() => repo.cashIn(
            amount: any(named: 'amount'),
            description: any(named: 'description'),
            createdBy: any(named: 'createdBy'),
            createdByName: any(named: 'createdByName'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) async => created);

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        amount: 500,
        description: 'Manager top-up',
      );

      expect(result.success, true);
      expect(result.data?.amount, 500);
      verify(() => repo.cashIn(
            amount: 500,
            description: 'Manager top-up',
            createdBy: 'u-admin',
            createdByName: 'admin user',
            notes: null,
          )).called(1);
      verify(() => logRepo.logActivity(any())).called(1);
    });

    test('cashier is denied with PermissionDeniedException', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        amount: 500,
        description: 'Top-up',
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
      verifyNever(() => repo.cashIn(
            amount: any(named: 'amount'),
            description: any(named: 'description'),
            createdBy: any(named: 'createdBy'),
            createdByName: any(named: 'createdByName'),
            notes: any(named: 'notes'),
          ));
    });

    test('staff is denied with PermissionDeniedException', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        amount: 500,
        description: 'Top-up',
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });

    test('rejects zero amount', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        amount: 0,
        description: 'Bad',
      );

      expect(result.success, false);
      expect(result.errorCode, 'invalid-amount');
    });

    test('rejects negative amount', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        amount: -100,
        description: 'Bad',
      );

      expect(result.success, false);
      expect(result.errorCode, 'invalid-amount');
    });

    test('inactive admin is denied (assertPermission honors isActive)', () async {
      final inactive =
          _user(UserRole.admin).copyWith(isActive: false);
      final result = await useCase.execute(
        actor: inactive,
        amount: 100,
        description: 'Top-up',
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });
  });
}
