import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/expense_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/daily_closing/get_daily_closing_summary_usecase.dart';

class _MockSaleRepository extends Mock implements SaleRepository {}

class _MockExpenseRepository extends Mock implements ExpenseRepository {}

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

void main() {
  late _MockSaleRepository sales;
  late _MockExpenseRepository expenses;
  late GetDailyClosingSummaryUseCase useCase;

  const summary = SalesSummary(
    totalSalesCount: 4,
    voidedSalesCount: 0,
    grossAmount: 1000,
    totalDiscounts: 0,
    netAmount: 1000,
    totalCost: 0,
    totalProfit: 1000,
    byPaymentMethod: {
      PaymentMethod.cash: 700,
      PaymentMethod.gcash: 300,
    },
  );

  setUp(() {
    sales = _MockSaleRepository();
    expenses = _MockExpenseRepository();
    useCase = GetDailyClosingSummaryUseCase(
      saleRepository: sales,
      expenseRepository: expenses,
    );

    when(() => sales.getSalesSummary(
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'))).thenAnswer((_) async => summary);
    when(() => expenses.getExpenses(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          category: any(named: 'category'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => [
          _exp(150, PaymentMethod.cash),
          _exp(50, PaymentMethod.gcash),
        ]);
  });

  test('computes the draft for an authorized actor', () async {
    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      date: DateTime(2026, 5, 28),
    );

    expect(result.success, true);
    final draft = result.data!;
    expect(draft.grossSales, 1000);
    expect(draft.cashSales, 700);
    expect(draft.nonCashSales, 300);
    expect(draft.totalExpenses, 200);
    expect(draft.cashExpenses, 150);
  });

  test('inactive user is denied', () async {
    final result = await useCase.execute(
      actor: _user(UserRole.cashier, active: false),
      date: DateTime(2026, 5, 28),
    );

    expect(result.success, false);
    expect(result.errorCode, 'permission-denied');
    verifyNever(() => sales.getSalesSummary(
        startDate: any(named: 'startDate'), endDate: any(named: 'endDate')));
  });
}
