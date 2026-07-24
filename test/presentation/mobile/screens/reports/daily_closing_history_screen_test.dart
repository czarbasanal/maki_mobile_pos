import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/daily_closing_history_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

final _date = DateTime(2026, 7, 20);

DailyClosingEntity _closing() => DailyClosingEntity(
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
      // 2000 (not 1450) so 'Sale items → management' = ₱1,550.00 collides
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

Widget _harness({SalesSummary? liveSummary}) => ProviderScope(
      overrides: [
        dailyClosingHistoryProvider
            .overrideWith((ref) => Stream.value([_closing()])),
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

    expect(find.text('Labor fees → mechanics'), findsNothing);
    await _expandFirstTile(tester);

    expect(find.text('Labor fees → mechanics'), findsOneWidget);
    // Unique here: the history detail has no labor-revenue row of its own.
    expect(find.text('₱450.00'), findsOneWidget);
    expect(find.text('Sale items → management'), findsOneWidget);
    expect(find.text('₱1,550.00'), findsOneWidget); // 2000 − 450
    expect(find.text('After close'), findsNothing);
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
}
