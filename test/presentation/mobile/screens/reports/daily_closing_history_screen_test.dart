import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/core/utils/mechanic_performance_report.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/daily_closing_history_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

final _date = DateTime(2026, 7, 20);

DailyClosingEntity _closing({
  double plateNoDp = 0,
  double plateNoDelivery = 0,
  double laborRevenue = 450,
  double gcashSales = 0,
  double mayaSales = 0,
  double salmonReceivable = 0,
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
      gcashSales: gcashSales,
      mayaSales: mayaSales,
      totalExpenses: 0,
      cashExpenses: 0,
      salmonReceivable: salmonReceivable,
      laborRevenue: laborRevenue,
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
        // Fetched on demand for a range now, not streamed wholesale.
        closingHistoryInRangeProvider
            .overrideWith((ref, range) async => [closing ?? _closing()]),
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
  // The list is fetched on demand now (FutureProvider), so it needs settling
  // rather than a fixed number of pumps.
  await tester.pumpAndSettle();
  // Scope to the tile: the range bar above the list has its own buttons, so
  // `InkWell.first` would tap "Other dates" rather than a closing.
  // `.first` goes on the descendant finder, not the inner one: applied to
  // `matching` it picks the first InkWell in the WHOLE tree — the range bar's
  // button — and then finds none of those inside the card.
  await tester.tap(find
      .descendant(
        of: find.byType(AppCard).first,
        matching: find.byType(InkWell),
      )
      .first);
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
    // Twice now: the Labor (service) row above shows the same ₱450 arriving
    // that the hand-over shows leaving.
    expect(find.text('₱450.00'), findsNWidgets(2));
    expect(find.text('To management'), findsOneWidget);
    expect(find.text('₱1,550.00'), findsOneWidget); // 2000 − 450
    expect(find.text('After close'), findsNothing);
  });

  testWidgets('breaks the summary into zones that each end in a result',
      (tester) async {
    await tester.pumpWidget(_harness(
      closing: _closing(
        plateNoDp: 250,
        plateNoDelivery: 100,
        gcashSales: 300,
        mayaSales: 120,
        salmonReceivable: 80,
      ),
    ));
    await tester.pump();
    await tester.pump();
    await _expandFirstTile(tester);

    // Each zone's result — the four numbers a reader should get by scanning.
    expect(find.text('Cash sales'), findsOneWidget);
    expect(find.text('Shop fees'), findsOneWidget);
    expect(find.text('Cash expenses'), findsOneWidget);
    expect(find.text('Counted cash'), findsOneWidget);
    // Tenders still break down non-cash sales.
    expect(find.text('GCash'), findsOneWidget);
    expect(find.text('Maya'), findsOneWidget);
    expect(find.text('Salmon receivable'), findsOneWidget);
  });

  testWidgets('names every zone, including the fees track',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump();
    await _expandFirstTile(tester);

    expect(find.text('SALES'), findsOneWidget);
    expect(find.text('SHOP FEES'), findsOneWidget);
    expect(find.text('EXPENSES'), findsOneWidget);
    expect(find.text('CASH RECONCILIATION'), findsOneWidget);
  });

  testWidgets('reports what changed before saying what to hand over',
      (tester) async {
    // Read in the other order the hand-over states a figure the reader has
    // not yet been told moved.
    await tester.pumpWidget(
        _harness(liveSummary: _summary(salesCount: 3, cash: 1750, labor: 750)));
    await tester.pump();
    await tester.pump();
    await _expandFirstTile(tester);

    final afterClose = tester.getTopLeft(find.text('After close')).dy;
    final handover = tester.getTopLeft(find.text('CASH HAND-OVER')).dy;
    expect(afterClose, lessThan(handover));
  });

  testWidgets('shows labor arriving, not only leaving', (tester) async {
    // Gross sales is parts-only, so without its own row the labor money never
    // appears on the way IN — it shows up only as "To mechanics" on the way
    // out, which reads as a second deduction of something already taken.
    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump();
    await _expandFirstTile(tester);

    expect(find.text('Gross sales (parts)'), findsOneWidget);
    expect(find.text('Labor (service)'), findsOneWidget);
  });

  testWidgets('keeps the labor row at zero on a parts-only day', (tester) async {
    await tester.pumpWidget(_harness(closing: _closing(laborRevenue: 0)));
    await tester.pump();
    await tester.pump();
    await _expandFirstTile(tester);

    expect(find.text('Labor (service)'), findsOneWidget);
  });

  testWidgets('always lines out Plate No DP and Delivery, even at zero',
      (tester) async {
    // A hidden row and an unimplemented feature look identical to a cashier
    // who was told to record a DP. ₱0.00 says "nothing was recorded"; nothing
    // at all says "this screen does not show it".
    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.pump();
    await _expandFirstTile(tester);

    expect(find.text('Plate No DP'), findsOneWidget);
    expect(find.text('Plate No Delivery'), findsOneWidget);
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
    // The split moved to the hand-over panel, which now supersedes its sealed
    // figures: the ₱750 whole-day labor is what to hand over, stated once.
    expect(find.text('Updated for management'), findsNothing);
    expect(find.text('For mechanics (whole day)'), findsNothing);
    expect(find.text('To mechanics'), findsOneWidget);
    // Twice: "Updated labor fees" on the After close card and "To mechanics"
    // on the hand-over below it — the same whole-day figure, once as the
    // result of the drift and once as the amount to hand over.
    expect(find.text('₱750.00'), findsNWidgets(2));
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
    expect(find.text('Plate No Delivery'), findsOneWidget);
    // Signed, because both move cash on hand — and in opposite directions.
    // The minus is U+2212, not a hyphen.
    expect(find.text('+₱250.00'), findsOneWidget);
    expect(find.text('−₱100.00'), findsOneWidget);
  });

}
