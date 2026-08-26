import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/utils/shop_time.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

ExpenseEntity _cashExpense(double amount) => ExpenseEntity(
      id: 'e',
      description: 'x',
      amount: amount,
      category: 'c',
      date: DateTime(2026, 5, 29),
      paidVia: PaymentMethod.cash,
      createdAt: DateTime(2026, 5, 29),
      createdBy: '',
      createdByName: '',
    );

SalesSummary _summary(double gross) => SalesSummary(
      totalSalesCount: 4,
      voidedSalesCount: 0,
      grossAmount: gross,
      totalDiscounts: 0,
      netAmount: gross,
      totalCost: 0,
      totalProfit: gross,
      byPaymentMethod: {
        PaymentMethod.cash: gross * 0.6,
        PaymentMethod.gcash: gross * 0.4,
      },
    );

/// [businessDayProvider] now holds a shop wall-clock midnight, and
/// [dailyClosingDataProvider] takes the "today" path only when its family key
/// equals that value — so the key has to be a shop wall date too.
final _todayKey = shopWall(2026, 8, 26);

/// A [businessDayProvider] override with no timer, pinned to [_todayKey].
class _FixedBusinessDayNotifier extends BusinessDayNotifier {
  @override
  DateTime build() => _todayKey;
}

void main() {
  test('today draft is sourced from the live sales summary + expenses', () async {
    final container = ProviderContainer(overrides: [
      businessDayProvider.overrideWith(_FixedBusinessDayNotifier.new),
      todaysSalesSummaryProvider.overrideWith((ref) async => _summary(1000)),
      expensesByDateRangeProvider
          .overrideWith((ref, p) async => [_cashExpense(100)]),
    ]);
    addTearDown(container.dispose);

    final draft =
        await container.read(dailyClosingDraftProvider(_todayKey).future);

    expect(draft.grossSales, 1000);
    expect(draft.cashSales, 600);
    expect(draft.nonCashSales, 400);
    expect(draft.cashExpenses, 100);
  });

  test('today draft recomputes when the live sales summary changes', () async {
    var gross = 1000.0;
    final container = ProviderContainer(overrides: [
      businessDayProvider.overrideWith(_FixedBusinessDayNotifier.new),
      todaysSalesSummaryProvider.overrideWith((ref) async => _summary(gross)),
      expensesByDateRangeProvider.overrideWith((ref, p) async => const []),
    ]);
    addTearDown(container.dispose);

    // Keep the draft alive so invalidation propagates.
    container.listen(dailyClosingDraftProvider(_todayKey), (_, __) {});

    final d1 = await container.read(dailyClosingDraftProvider(_todayKey).future);
    expect(d1.grossSales, 1000);

    gross = 1500;
    container.invalidate(todaysSalesSummaryProvider);

    final d2 = await container.read(dailyClosingDraftProvider(_todayKey).future);
    expect(d2.grossSales, 1500);
  });
}
