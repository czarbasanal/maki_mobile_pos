import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/core/utils/mechanic_performance_report.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/daily_closing_history_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

final _date = DateTime(2026, 7, 20);

DailyClosingEntity _closing({
  double plateNoDp = 0,
  double plateNoDelivery = 0,
}) =>
    DailyClosingEntity(
      plateNoDp: plateNoDp,
      plateNoDelivery: plateNoDelivery,
      id: '2026-07-20',
      businessDate: _date,
      grossSales: 1000,
      netSales: 1000,
      totalDiscounts: 0,
      cashSales: 1450,
      nonCashSales: 0,
      gcashSales: 0,
      mayaSales: 0,
      totalExpenses: 0,
      cashExpenses: 0,
      salmonReceivable: 0,
      laborRevenue: 450,
      openingFloat: 0,
      expectedCash: 1450,
      // 2000 (not 1450) so 'To management' = ₱1,550.00 collides
      // with no other detail row (gross renders ₱1,000.00).
      countedCash: 2000,
      variance: 550,
      salesCount: 2,
      voidedCount: 0,
      closedBy: 'u',
      closedByName: 'U',
      closedAt: DateTime(2026, 7, 20, 18, 0),
    );

SalesSummary _summary({int salesCount = 2, double cash = 1450, double labor = 450}) =>
    SalesSummary(
      totalSalesCount: salesCount,
      voidedSalesCount: 0,
      grossAmount: 1000,
      totalDiscounts: 0,
      netAmount: 1000,
      totalCost: 0,
      totalProfit: 1000,
      byPaymentMethod: {PaymentMethod.cash: cash},
      laborRevenue: labor,
      laborProfit: labor,
    );

MechanicPerformanceStat _stat(String name, double labor) =>
    MechanicPerformanceStat(
      mechanicId: name,
      mechanicName: name,
      jobCount: 1,
      totalRevenue: labor,
      laborTotal: labor,
    );

Widget _harness({
  SalesSummary? liveSummary,
  DailyClosingEntity? closing,
  List<MechanicPerformanceStat>? mechanics,
}) =>
    ProviderScope(
      overrides: [
        mechanicPerformanceReportProvider.overrideWith((ref, params) async =>
            MechanicPerformanceReportData(
              totalRevenue: 0,
              jobCount: 0,
              byMechanic: mechanics ?? const [],
            )),
        dailyClosingHistoryProvider
            .overrideWith((ref) => Stream.value([closing ?? _closing()])),
        dailyClosingDataProvider.overrideWith((ref, date) async =>
            DailyClosingData(
              businessDate: date,
              summary: liveSummary ?? _summary(),
              expenses: const [],
            )),
      ],
      child: const MaterialApp(home: DailyClosingHistoryScreen()),
    );

Future<void> _expandFirstTile(WidgetTester tester) async {
  await tester.tap(find.byType(InkWell).first);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('expanded day shows handoff rows; no After close when in sync',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump();

    expect(find.text('To mechanics'), findsNothing);
    await _expandFirstTile(tester);

    expect(find.text('To mechanics'), findsOneWidget);
    // Unique here: the history detail has no labor-revenue row of its own.
    expect(find.text('₱450.00'), findsOneWidget);
    expect(find.text('To management'), findsOneWidget);
    expect(find.text('₱1,550.00'), findsOneWidget); // 2000 − 450
    expect(find.text('After close'), findsNothing);
  });

  testWidgets('names each mechanic under the mechanics line',
      (tester) async {
    await tester.pumpWidget(_harness(
      mechanics: [_stat('Jun', 300), _stat('Rico', 150)],
    ));
    await tester.pump();
    await tester.pump();
    await _expandFirstTile(tester);

    expect(find.text('Jun'), findsOneWidget);
    expect(find.text('₱300.00'), findsOneWidget);
    expect(find.text('Rico'), findsOneWidget);
    expect(find.text('₱150.00'), findsOneWidget);
    // 300 + 150 matches the frozen ₱450 total, so no mismatch note.
    expect(find.textContaining('Named shares total'), findsNothing);
  });

  testWidgets('expanded day that drifted shows the After close block',
      (tester) async {
    // One extra cash labor-only sale (₱300) after that day closed.
    await tester.pumpWidget(
        _harness(liveSummary: _summary(salesCount: 3, cash: 1750, labor: 750)));
    await tester.pump();
    await tester.pump();
    await _expandFirstTile(tester);

    expect(find.text('After close'), findsOneWidget);
    expect(find.text('Updated for management'), findsOneWidget);
    expect(find.text('For mechanics (whole day)'), findsOneWidget);
    expect(find.text('₱750.00'), findsOneWidget);
  });

  testWidgets('history lists Plate No DP and Delivery so expected cash reconciles',
      (tester) async {
    // Expected cash = float + cashSales − cashExpenses + plateDp − plateDelivery.
    // Every other term already had a row; without these two the figure could
    // not be checked against what was on screen.
    await tester.pumpWidget(
      _harness(closing: _closing(plateNoDp: 250, plateNoDelivery: 100)),
    );
    await tester.pump();
    await tester.pump();
    await _expandFirstTile(tester);

    expect(find.text('Plate No DP'), findsOneWidget);
    expect(find.text('₱250.00'), findsOneWidget);
    expect(find.text('Plate No Delivery'), findsOneWidget);
    expect(find.text('₱100.00'), findsOneWidget);
  });

  testWidgets('no plate rows on a day that had none', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump();
    await _expandFirstTile(tester);

    expect(find.text('Plate No DP'), findsNothing);
    expect(find.text('Plate No Delivery'), findsNothing);
  });
}
