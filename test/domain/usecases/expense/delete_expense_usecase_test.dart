import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/expense_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/expense/delete_expense_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockExpenseRepository extends Mock implements ExpenseRepository {}

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

ExpenseEntity _expense({String desc = 'Coffee'}) => ExpenseEntity(
      id: 'exp-1',
      description: desc,
      amount: 50,
      category: 'Office supplies',
      date: DateTime(2025, 1, 1),
      createdAt: DateTime(2025, 1, 1),
      createdBy: 'u-cashier',
      createdByName: 'cashier user',
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockExpenseRepository repo;
  late _MockActivityLogRepository logRepo;
  late DeleteExpenseUseCase useCase;

  setUp(() {
    repo = _MockExpenseRepository();
    logRepo = _MockActivityLogRepository();
    useCase = DeleteExpenseUseCase(
      repository: repo,
      logger: ActivityLogger(logRepo),
    );

    when(() => repo.deleteExpense(any())).thenAnswer((_) async {});
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  group('DeleteExpenseUseCase', () {
    test('admin deletes successfully', () async {
      when(() => repo.getExpenseById('exp-1'))
          .thenAnswer((_) async => _expense());

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        expenseId: 'exp-1',
      );

      expect(result.success, true);
      verify(() => repo.deleteExpense('exp-1')).called(1);
      verify(() => logRepo.logActivity(any())).called(1);
    });

    test('cashier is denied (deleteExpense is admin-only)', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        expenseId: 'exp-1',
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
      verifyNever(() => repo.deleteExpense(any()));
      verifyNever(() => repo.getExpenseById(any()));
    });

    test('staff is denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        expenseId: 'exp-1',
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });

    test('still deletes when prior fetch returns null (graceful)', () async {
      when(() => repo.getExpenseById('exp-missing'))
          .thenAnswer((_) async => null);

      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        expenseId: 'exp-missing',
      );

      expect(result.success, true);
      verify(() => repo.deleteExpense('exp-missing')).called(1);
      verify(() => logRepo.logActivity(any())).called(1);
    });

    test('inactive admin is denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin, isActive: false),
        expenseId: 'exp-1',
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });
  });
}
