import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/petty_cash_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/petty_cash_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/petty_cash/cash_out_usecase.dart';
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

PettyCashEntity _record({double amount = 100, double balance = 900}) =>
    PettyCashEntity(
      id: 'rec-1',
      type: PettyCashType.cashOut,
      amount: amount,
      balance: balance,
      description: 'Withdrawal',
      createdAt: DateTime(2025, 1, 1, 10),
      createdBy: 'u-admin',
      createdByName: 'admin user',
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockPettyCashRepository repo;
  late _MockActivityLogRepository logRepo;
  late CashOutUseCase useCase;

  setUp(() {
    repo = _MockPettyCashRepository();
    logRepo = _MockActivityLogRepository();
    useCase = CashOutUseCase(
      repository: repo,
      logger: ActivityLogger(logRepo),
    );

    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  group('CashOutUseCase', () {
    test('admin withdraws successfully when balance is sufficient', () async {
      when(() => repo.getCurrentBalance()).thenAnswer((_) async => 1000);
      when(() => repo.cashOut(
            amount: any(named: 'amount'),
            description: any(named: 'description'),
            createdBy: any(named: 'createdBy'),
            createdByName: any(named: 'createdByName'),
            referenceId: any(named: 'referenceId'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) async => _record(amount: 200, balance: 800));

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        amount: 200,
        description: 'Supplier payment',
      );

      expect(result.success, true);
      expect(result.data?.balance, 800);
      verify(() => repo.cashOut(
            amount: 200,
            description: 'Supplier payment',
            createdBy: 'u-admin',
            createdByName: 'admin user',
            referenceId: null,
            notes: null,
          )).called(1);
    });

    test('blocks withdrawal that exceeds available balance', () async {
      when(() => repo.getCurrentBalance()).thenAnswer((_) async => 50);

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        amount: 100,
        description: 'Too much',
      );

      expect(result.success, false);
      expect(result.errorCode, 'insufficient-balance');
      verifyNever(() => repo.cashOut(
            amount: any(named: 'amount'),
            description: any(named: 'description'),
            createdBy: any(named: 'createdBy'),
            createdByName: any(named: 'createdByName'),
            referenceId: any(named: 'referenceId'),
            notes: any(named: 'notes'),
          ));
    });

    test('cashier is denied even with sufficient balance', () async {
      when(() => repo.getCurrentBalance()).thenAnswer((_) async => 1000);

      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        amount: 100,
        description: 'Drink',
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
      verifyNever(() => repo.cashOut(
            amount: any(named: 'amount'),
            description: any(named: 'description'),
            createdBy: any(named: 'createdBy'),
            createdByName: any(named: 'createdByName'),
            referenceId: any(named: 'referenceId'),
            notes: any(named: 'notes'),
          ));
    });

    test('staff is denied', () async {
      when(() => repo.getCurrentBalance()).thenAnswer((_) async => 1000);

      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        amount: 100,
        description: 'Lunch',
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });

    test('rejects zero amount', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        amount: 0,
        description: 'Zero',
      );

      expect(result.success, false);
      expect(result.errorCode, 'invalid-amount');
    });

    test('rejects negative amount', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        amount: -50,
        description: 'Negative',
      );

      expect(result.success, false);
      expect(result.errorCode, 'invalid-amount');
    });

    test('exact-balance withdrawal is permitted (boundary)', () async {
      when(() => repo.getCurrentBalance()).thenAnswer((_) async => 100);
      when(() => repo.cashOut(
            amount: any(named: 'amount'),
            description: any(named: 'description'),
            createdBy: any(named: 'createdBy'),
            createdByName: any(named: 'createdByName'),
            referenceId: any(named: 'referenceId'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) async => _record(amount: 100, balance: 0));

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        amount: 100,
        description: 'Drain to zero',
      );

      expect(result.success, true);
      expect(result.data?.balance, 0);
    });
  });
}
