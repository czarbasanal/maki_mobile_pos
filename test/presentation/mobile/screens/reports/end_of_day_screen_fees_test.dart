import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/end_of_day_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Day with parts ₱1,000 + shop fees ₱150, all cash (drawer holds ₱1,150).
SalesSummary _summary() => const SalesSummary(
      totalSalesCount: 2,
      voidedSalesCount: 0,
      grossAmount: 1000,
      totalDiscounts: 0,
      netAmount: 1000,
      totalCost: 0,
      totalProfit: 1000,
      byPaymentMethod: {PaymentMethod.cash: 1150},
      feesRevenue: 150,
    );

DailyClosingData _data(DateTime date) => DailyClosingData(
      businessDate: date,
      summary: _summary(),
      expenses: const [],
    );

DailyClosingEntity _closing(DateTime date) => DailyClosingEntity(
      id: 'today',
      businessDate: date,
      grossSales: 1000,
      netSales: 1000,
      totalDiscounts: 0,
      cashSales: 1150,
      nonCashSales: 0,
      gcashSales: 0,
      mayaSales: 0,
      totalExpenses: 0,
      cashExpenses: 0,
      salmonReceivable: 0,
      feesRevenue: 150,
      openingFloat: 0,
      expectedCash: 1150,
      countedCash: 1150,
      variance: 0,
      salesCount: 2,
      voidedCount: 0,
      closedBy: 'u',
      closedByName: 'U',
      closedAt: DateTime(2026, 7, 24, 18, 0),
    );

Widget _harness({DailyClosingEntity? closing}) => ProviderScope(
      overrides: [
        dailyClosingForDateProvider.overrideWith((ref, date) async => closing),
        dailyClosingDataProvider.overrideWith((ref, date) async => _data(date)),
      ],
      child: const MaterialApp(home: EndOfDayScreen()),
    );

void main() {
  testWidgets('review: Sales card shows Shop fees when feesRevenue > 0',
      (tester) async {
    await tester.pumpWidget(_harness(closing: null));
    await tester.pump();
    await tester.pump();

    expect(find.text('Shop fees'), findsOneWidget);
    expect(find.text('₱150.00'), findsOneWidget);
  });

  testWidgets('closed view: Sales card shows Shop fees from the frozen record',
      (tester) async {
    final closing = _closing(DateTime(2026, 7, 24));
    await tester.pumpWidget(_harness(closing: closing));
    await tester.pump();
    await tester.pump();

    expect(find.text('Shop fees'), findsOneWidget);
    expect(find.text('₱150.00'), findsOneWidget);
  });
}
