import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/daily_closing_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/expense_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/daily_closing/close_day_usecase.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockSaleRepository extends Mock implements SaleRepository {}

class _MockExpenseRepository extends Mock implements ExpenseRepository {}

class _MockClosingRepository extends Mock implements DailyClosingRepository {}

class _MockActivityLogRepository extends Mock
    implements ActivityLogRepository {}

class _FakeClosing extends Fake implements DailyClosingEntity {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _user(UserRole role, {bool active = true}) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: active,
      createdAt: DateTime(2025, 1, 1),
    );

ExpenseEntity _exp(double amount, PaymentMethod paidVia) => ExpenseEntity(
      id: 'e',
      description: 'x',
      amount: amount,
      category: 'c',
      date: DateTime(2026, 5, 28),
      paidVia: paidVia,
      createdAt: DateTime(2026, 5, 28),
      createdBy: '',
      createdByName: '',
    );

DailyClosingEntity _existingClosing() => DailyClosingEntity(
      id: '2026-05-28',
      businessDate: DateTime(2026, 5, 28),
      grossSales: 0,
      netSales: 0,
      totalDiscounts: 0,
      cashSales: 0,
      nonCashSales: 0,
      gcashSales: 0,
      mayaSales: 0,
      totalExpenses: 0,
      cashExpenses: 0,
      salmonReceivable: 0,
      openingFloat: 0,
      expectedCash: 0,
      countedCash: 0,
      variance: 0,
      salesCount: 0,
      voidedCount: 0,
      closedBy: 'someone',
      closedByName: 'Someone',
      closedAt: DateTime(2026, 5, 28),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeClosing());
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockSaleRepository sales;
  late _MockExpenseRepository expenses;
  late _MockClosingRepository closings;
  late _MockActivityLogRepository logRepo;
  late CloseDayUseCase useCase;

  const summary = SalesSummary(
    totalSalesCount: 3,
    voidedSalesCount: 0,
    grossAmount: 1000,
    totalDiscounts: 0,
    netAmount: 1000,
    totalCost: 0,
    totalProfit: 1000,
    byPaymentMethod: {PaymentMethod.cash: 700, PaymentMethod.gcash: 300},
  );

  setUp(() {
    sales = _MockSaleRepository();
    expenses = _MockExpenseRepository();
    closings = _MockClosingRepository();
    logRepo = _MockActivityLogRepository();
    useCase = CloseDayUseCase(
      closingRepository: closings,
      saleRepository: sales,
      expenseRepository: expenses,
      logger: ActivityLogger(logRepo),
    );

    when(() => sales.getSalesSummary(
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'))).thenAnswer((_) async => summary);
    when(() => expenses.getExpenses(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          category: any(named: 'category'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => [_exp(100, PaymentMethod.cash)]);
    when(() => closings.getClosing(any())).thenAnswer((_) async => null);
    when(() => closings.saveClosing(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as DailyClosingEntity);
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  test('computes expectedCash and variance and saves the closing', () async {
    final captured = <DailyClosingEntity>[];
    when(() => closings.saveClosing(any())).thenAnswer((inv) async {
      final c = inv.positionalArguments.first as DailyClosingEntity;
      captured.add(c);
      return c;
    });

    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      date: DateTime(2026, 5, 28),
      openingFloat: 2000,
      countedCash: 2590,
      notes: null,
    );

    expect(result.success, true);
    final saved = captured.single;
    expect(saved.id, '2026-05-28');
    expect(saved.cashSales, 700);
    expect(saved.cashExpenses, 100);
    expect(saved.expectedCash, 2600); // 2000 + 700 - 100
    expect(saved.variance, -10); // 2590 - 2600
    expect(saved.closedBy, 'u-cashier');
    verify(() => logRepo.logActivity(any())).called(1);
  });

  test('plate-no DP adds and delivery subtracts from expected cash', () async {
    final captured = <DailyClosingEntity>[];
    when(() => closings.saveClosing(any())).thenAnswer((inv) async {
      final c = inv.positionalArguments.first as DailyClosingEntity;
      captured.add(c);
      return c;
    });

    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      date: DateTime(2026, 5, 28),
      openingFloat: 2000,
      countedCash: 0,
      plateNoDp: 300,
      plateNoDelivery: 50,
    );

    expect(result.success, true);
    final saved = captured.single;
    expect(saved.plateNoDp, 300);
    expect(saved.plateNoDelivery, 50);
    // 2000 float + 700 cash - 100 cash exp + 300 dp - 50 delivery = 2850
    expect(saved.expectedCash, 2850);
  });

  test('rejects when the day is already closed', () async {
    when(() => closings.getClosing(any()))
        .thenAnswer((_) async => _existingClosing());

    final result = await useCase.execute(
      actor: _user(UserRole.admin),
      date: DateTime(2026, 5, 28),
      openingFloat: 0,
      countedCash: 0,
    );

    expect(result.success, false);
    expect(result.errorCode, 'already-closed');
    verifyNever(() => closings.saveClosing(any()));
  });

  test('inactive user is denied', () async {
    final result = await useCase.execute(
      actor: _user(UserRole.cashier, active: false),
      date: DateTime(2026, 5, 28),
      openingFloat: 0,
      countedCash: 0,
    );

    expect(result.success, false);
    expect(result.errorCode, 'permission-denied');
    verifyNever(() => closings.saveClosing(any()));
  });
}
