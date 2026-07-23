import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/end_of_day_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/daily_closing_provider.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  const emptySummary = SalesSummary(
    totalSalesCount: 0,
    voidedSalesCount: 0,
    grossAmount: 0,
    totalDiscounts: 0,
    netAmount: 0,
    totalCost: 0,
    totalProfit: 0,
    byPaymentMethod: {},
  );

  // Live data matching the closing → no post-close drift banner.
  final liveData = DailyClosingData(
    businessDate: today,
    summary: emptySummary,
    expenses: const [],
  );

  DailyClosingEntity closing({
    double plateNoDp = 0,
    double plateNoDelivery = 0,
    List<double> plateNoDpAmounts = const [],
    List<double> plateNoDeliveryAmounts = const [],
  }) =>
      DailyClosingEntity(
        id: 'closing-1',
        businessDate: today,
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
        plateNoDp: plateNoDp,
        plateNoDelivery: plateNoDelivery,
        plateNoDpAmounts: plateNoDpAmounts,
        plateNoDeliveryAmounts: plateNoDeliveryAmounts,
        openingFloat: 1000,
        expectedCash: 1000 + plateNoDp - plateNoDelivery,
        countedCash: 1000 + plateNoDp - plateNoDelivery,
        variance: 0,
        salesCount: 0,
        voidedCount: 0,
        closedBy: 'u1',
        closedByName: 'Ada',
        closedAt: today.add(const Duration(hours: 20)),
      );

  Future<void> pump(WidgetTester tester, DailyClosingEntity saved) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyClosingForDateProvider(today)
              .overrideWith((ref) async => saved),
          dailyClosingDataProvider(today)
              .overrideWith((ref) async => liveData),
        ],
        child: const MaterialApp(home: EndOfDayScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('itemizes each plate amount when lists are persisted',
      (tester) async {
    await pump(
      tester,
      closing(
        plateNoDp: 350,
        plateNoDelivery: 50,
        plateNoDpAmounts: const [100, 250],
        plateNoDeliveryAmounts: const [50],
      ),
    );

    expect(find.text('Plate No DP · 2 entries'), findsOneWidget);
    expect(find.text('₱100.00'), findsOneWidget);
    expect(find.text('₱250.00'), findsOneWidget);
    expect(find.text('Plate No Delivery · 1 entry'), findsOneWidget);
    // ₱50.00 appears twice: the delivery total AND its single entry row.
    expect(find.text('₱50.00'), findsNWidgets(2));
  });

  testWidgets('old docs (scalars only) keep the single KV rows',
      (tester) async {
    await pump(tester, closing(plateNoDp: 300));

    expect(find.text('Plate No DP'), findsOneWidget);
    expect(find.text('₱300.00'), findsOneWidget);
    expect(find.textContaining('entries'), findsNothing);
    expect(find.textContaining('Entry'), findsNothing);
  });
}
