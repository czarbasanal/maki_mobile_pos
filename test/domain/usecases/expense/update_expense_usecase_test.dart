import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/expense_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/expense/update_expense_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockExpenseRepository extends Mock implements ExpenseRepository {}

class _MockActivityLogRepository extends Mock implements ActivityLogRepository {
}

class _FakeExpense extends Fake implements ExpenseEntity {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _user(UserRole role, {bool isActive = true}) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: isActive,
      createdAt: DateTime(2025, 1, 1),
    );

ExpenseEntity _expense({String desc = 'Coffee', double amount = 50}) =>
    ExpenseEntity(
      id: 'exp-1',
      description: desc,
      amount: amount,
      category: 'Office supplies',
      date: DateTime(2025, 1, 1),
      createdAt: DateTime(2025, 1, 1),
      createdBy: 'u-cashier',
      createdByName: 'cashier user',
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeExpense());
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockExpenseRepository repo;
  late _MockActivityLogRepository logRepo;
  late UpdateExpenseUseCase useCase;

  setUp(() {
    repo = _MockExpenseRepository();
    logRepo = _MockActivityLogRepository();
    useCase = UpdateExpenseUseCase(
      repository: repo,
      logger: ActivityLogger(logRepo),
    );

    when(() => repo.updateExpense(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as ExpenseEntity);
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  group('UpdateExpenseUseCase', () {
    test('admin updates expense successfully', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin),
        expense: _expense(desc: 'Updated coffee', amount: 60),
      );

      expect(result.success, true);
      expect(result.data?.description, 'Updated coffee');
      verify(() => repo.updateExpense(any())).called(1);
      verify(() => logRepo.logActivity(any())).called(1);
    });

    test('admin update stamps updatedBy + updatedAt', () async {
      final captured = <ExpenseEntity>[];
      when(() => repo.updateExpense(any())).thenAnswer((inv) async {
        final stamped = inv.positionalArguments.first as ExpenseEntity;
        captured.add(stamped);
        return stamped;
      });

      await useCase.execute(
        actor: _user(UserRole.admin),
        expense: _expense(),
      );

      expect(captured.single.updatedBy, 'u-admin');
      expect(captured.single.updatedAt, isNotNull);
    });

    test('cashier is denied (editExpense is admin-only)', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        expense: _expense(),
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
      verifyNever(() => repo.updateExpense(any()));
    });

    test('staff is denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.staff),
        expense: _expense(),
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
      verifyNever(() => repo.updateExpense(any()));
    });

    test('inactive admin is denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.admin, isActive: false),
        expense: _expense(),
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
    });
  });
}
