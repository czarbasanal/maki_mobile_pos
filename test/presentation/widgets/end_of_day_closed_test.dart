import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/entities/expense_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/business_day_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/daily_closing_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/unsettled_day_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/end_of_day_screen.dart';

/// A [businessDayProvider] override with no timer — see
/// end_of_day_plate_amount_submit_test.dart for why a real (unoverridden)
/// build would trip flutter_test's "no pending timers" invariant.
class _FixedBusinessDayNotifier extends BusinessDayNotifier {
  _FixedBusinessDayNotifier(this._fixed);
  final DateTime _fixed;

  @override
  DateTime build() => _fixed;
}

DailyClosingEntity _closing(DateTime d) => DailyClosingEntity(
      id: 'd1',
      businessDate: d,
      grossSales: 8420,
      netSales: 8300,
      totalDiscounts: 120,
      cashSales: 5200,
      nonCashSales: 3220,
      gcashSales: 2240,
      mayaSales: 980,
      totalExpenses: 430,
      cashExpenses: 430,
      salmonReceivable: 0,
      laborRevenue: 650,
      openingFloat: 1000,
      expectedCash: 5770,
      countedCash: 5750,
      variance: -20,
      salesCount: 14,
      voidedCount: 0,
      closedBy: 'u1',
      closedByName: 'Maria Santos',
      closedAt: DateTime(2026, 6, 27, 18, 32),
    );

// Live data with two more sales (+₱1,300 gross, +₱800 cash) than the
// snapshot → triggers the post-close warning + After-close card.
DailyClosingData _data(DateTime d) => DailyClosingData(
      businessDate: d,
      summary: const SalesSummary(
        totalSalesCount: 16,
        voidedSalesCount: 0,
        grossAmount: 9720,
        totalDiscounts: 120,
        netAmount: 9600,
        totalCost: 0,
        totalProfit: 9600,
        byPaymentMethod: {
          PaymentMethod.cash: 6000,
          PaymentMethod.gcash: 2540,
          PaymentMethod.maya: 980,
        },
        laborRevenue: 650,
      ),
      expenses: [
        ExpenseEntity(
          id: 'e1',
          description: 'Diesel',
          amount: 430,
          category: 'Fuel',
          date: d,
          createdAt: d,
          createdBy: '',
          createdByName: '',
        ),
      ],
    );

void main() {
  final now = DateTime.now();
  final dayStart = DateTime(now.year, now.month, now.day);

  Widget harness() => ProviderScope(
        overrides: [
          businessDayProvider
              .overrideWith(() => _FixedBusinessDayNotifier(dayStart)),
          unsettledBusinessDayProvider.overrideWith((ref) async => null),
          dailyClosingForDateProvider
              .overrideWith((ref, date) async => _closing(dayStart)),
          dailyClosingDataProvider
              .overrideWith((ref, date) async => _data(dayStart)),
        ],
        child: const MaterialApp(home: EndOfDayScreen()),
      );

  testWidgets(
      'closed view shows closed-by banner, post-close warning, and After close',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.badgeCheck), findsOneWidget);
    expect(find.textContaining('Closed by Maria Santos'), findsOneWidget);
    expect(find.byIcon(LucideIcons.alertTriangle), findsOneWidget);
    expect(find.text('After close'), findsOneWidget);
    // Stated twice by design: once as the result of the drift math on the
    // After close card, once as the sum of the two hand-over destinations.
    // They read the same value from the same source.
    expect(find.text('Updated cash on hand'), findsNWidgets(2));
    expect(find.text('Close Day'), findsNothing);
  });
}
