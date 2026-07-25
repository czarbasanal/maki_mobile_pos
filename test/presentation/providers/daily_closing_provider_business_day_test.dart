// Proves the Task 2 swap: dailyClosingDataProvider's isToday comparison
// watches [businessDayProvider] instead of taking a `DateTime.now()`
// snapshot, so the SAME family entry (same DateTime key) flips from the
// live "today" path onto the one-shot past-day path when the clock rolls
// past midnight while the provider is still alive.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/expense_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/daily_closing/get_daily_closing_summary_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/business_day_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/daily_closing_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/expense_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';

class _MockSaleRepository extends Mock implements SaleRepository {}

class _MockExpenseRepository extends Mock implements ExpenseRepository {}

class _FixedBusinessDayNotifier extends BusinessDayNotifier {
  _FixedBusinessDayNotifier(this._initial);
  final DateTime _initial;

  @override
  DateTime build() => _initial;

  void set(DateTime day) => state = day;
}

UserEntity _admin() => UserEntity(
      id: 'u-admin',
      email: 'admin@x.com',
      displayName: 'Admin',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

const _todayLiveSummary = SalesSummary(
  totalSalesCount: 1,
  voidedSalesCount: 0,
  grossAmount: 111,
  totalDiscounts: 0,
  netAmount: 111,
  totalCost: 0,
  totalProfit: 111,
  byPaymentMethod: {},
);

const _pastDaySummary = SalesSummary(
  totalSalesCount: 2,
  voidedSalesCount: 0,
  grossAmount: 222,
  totalDiscounts: 0,
  netAmount: 222,
  totalCost: 0,
  totalProfit: 222,
  byPaymentMethod: {},
);

void main() {
  test(
      'the same family date flips from the live-today path to the past-day '
      'use-case path when businessDayProvider advances past it', () async {
    // Past-day path: a distinct fake repo pair wired straight into the
    // use-case provider, returning a value the "today" path never
    // produces — lets the test tell the two code paths apart.
    final pastSaleRepo = _MockSaleRepository();
    when(() => pastSaleRepo.getSalesSummary(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        )).thenAnswer((_) async => _pastDaySummary);
    final pastExpenseRepo = _MockExpenseRepository();
    when(() => pastExpenseRepo.getExpenses(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => <ExpenseEntity>[]);

    final dayNotifier = _FixedBusinessDayNotifier(DateTime(2026, 7, 24));
    final target = DateTime(2026, 7, 24);

    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
      businessDayProvider.overrideWith(() => dayNotifier),
      // "Today" path plumbing (todaysSalesSummaryProvider chain).
      todaysSalesSummaryProvider.overrideWith((ref) async => _todayLiveSummary),
      expensesByDateRangeProvider
          .overrideWith((ref, params) async => <ExpenseEntity>[]),
      // Past-day path plumbing.
      getDailyClosingSummaryUseCaseProvider.overrideWithValue(
        GetDailyClosingSummaryUseCase(
          saleRepository: pastSaleRepo,
          expenseRepository: pastExpenseRepo,
        ),
      ),
    ]);
    addTearDown(container.dispose);
    final sub =
        container.listen(dailyClosingDataProvider(target), (_, __) {});
    addTearDown(sub.close);

    // While businessDayProvider says today == target, the family entry for
    // `target` takes the live "today" path.
    final beforeFlip =
        await container.read(dailyClosingDataProvider(target).future);
    expect(beforeFlip.summary.grossAmount, 111);

    // Advance the clock past `target` and re-read the SAME family key —
    // the isToday comparison must flip and route to the past-day use case.
    dayNotifier.set(DateTime(2026, 7, 25));
    await Future<void>.delayed(Duration.zero);
    final afterFlip =
        await container.read(dailyClosingDataProvider(target).future);
    expect(afterFlip.summary.grossAmount, 222,
        reason: 'businessDayProvider flip must reroute the same date key '
            'from the live-today path onto the past-day use case');
  });
}
