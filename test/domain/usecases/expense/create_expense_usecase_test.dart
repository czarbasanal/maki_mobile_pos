import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/expense_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/expense/create_expense_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockExpenseRepository extends Mock implements ExpenseRepository {}

class _MockActivityLogRepository extends Mock implements ActivityLogRepository {
}

class _FakeExpense extends Fake implements ExpenseEntity {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _user(UserRole role) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    );

ExpenseEntity _expense({String desc = 'Pen and paper'}) => ExpenseEntity(
      id: '',
      description: desc,
      amount: 75,
      category: 'Office supplies',
      date: DateTime(2025, 1, 1),
      createdAt: DateTime(2025, 1, 1),
      createdBy: '',
      createdByName: '',
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeExpense());
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockExpenseRepository repo;
  late _MockActivityLogRepository logRepo;
  late CreateExpenseUseCase useCase;

  setUp(() {
    repo = _MockExpenseRepository();
    logRepo = _MockActivityLogRepository();
    useCase = CreateExpenseUseCase(
      repository: repo,
      logger: ActivityLogger(logRepo),
    );

    when(() => repo.createExpense(any())).thenAnswer(
        (inv) async => (inv.positionalArguments.first as ExpenseEntity)
            .copyWith(id: 'exp-1'));
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  group('CreateExpenseUseCase', () {
    for (final role in [UserRole.cashier, UserRole.staff, UserRole.admin]) {
      test('${role.value} can create an expense (addExpense is granted to all)',
          () async {
        final result = await useCase.execute(
          actor: _user(role),
          expense: _expense(),
        );

        expect(result.success, true);
        expect(result.data?.id, 'exp-1');
        verify(() => repo.createExpense(any())).called(1);
      });
    }

    test('stamps actor onto created expense', () async {
      final captured = <ExpenseEntity>[];
      when(() => repo.createExpense(any())).thenAnswer((inv) async {
        final stamped = inv.positionalArguments.first as ExpenseEntity;
        captured.add(stamped);
        return stamped.copyWith(id: 'exp-2');
      });

      await useCase.execute(
        actor: _user(UserRole.cashier),
        expense: _expense(),
      );

      expect(captured.single.createdBy, 'u-cashier');
      expect(captured.single.createdByName, 'cashier user');
    });

    test('inactive user is denied', () async {
      final inactive = _user(UserRole.cashier).copyWith(isActive: false);
      final result = await useCase.execute(
        actor: inactive,
        expense: _expense(),
      );

      expect(result.success, false);
      expect(result.errorCode, 'permission-denied');
      verifyNever(() => repo.createExpense(any()));
    });

    test('writes an activity log entry on success', () async {
      await useCase.execute(
        actor: _user(UserRole.staff),
        expense: _expense(),
      );

      verify(() => logRepo.logActivity(any())).called(1);
    });
  });
}
