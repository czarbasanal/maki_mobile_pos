import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/end_of_day_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// Day with parts ₱1,000 + labor ₱450, all cash (drawer holds ₱1,450).
SalesSummary _summary({
  int salesCount = 2,
  double cash = 1450,
  double labor = 450,
}) =>
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

DailyClosingData _data(DateTime date, {SalesSummary? summary}) =>
    DailyClosingData(
      businessDate: date,
      summary: summary ?? _summary(),
      expenses: const [],
    );

DailyClosingEntity _closing(DateTime date) => DailyClosingEntity(
      id: 'today',
      businessDate: date,
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
      // 2000 (not 1450) so 'Sale items → management' = ₱1,550.00 is a
      // string no other row on the screen renders (gross is ₱1,000.00).
      countedCash: 2000,
      variance: 550,
      salesCount: 2,
      voidedCount: 0,
      closedBy: 'u',
      closedByName: 'U',
      closedAt: DateTime(2026, 7, 24, 18, 0),
    );

Widget _harness({
  DailyClosingEntity? closing,
  SalesSummary? liveSummary,
}) =>
    ProviderScope(
      overrides: [
        dailyClosingForDateProvider
            .overrideWith((ref, date) async => closing),
        dailyClosingDataProvider.overrideWith(
            (ref, date) async => _data(date, summary: liveSummary)),
      ],
      child: const MaterialApp(home: EndOfDayScreen()),
    );

void main() {
  testWidgets('review: handoff rows appear only once counted cash is entered',
      (tester) async {
    await tester.pumpWidget(_harness(closing: null));
    await tester.pump();
    await tester.pump();

    expect(find.text('Labor fees → mechanics'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('counted-cash')));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('counted-cash')),
        matching: find.byType(TextFormField),
      ),
      '3000',
    );
    await tester.pump();

    expect(find.text('Labor fees → mechanics'), findsOneWidget);
    // ₱450.00 appears twice: 'Labor revenue (service)' in the Sales card
    // plus the new handoff row.
    expect(find.text('₱450.00'), findsNWidgets(2));
    expect(find.text('Sale items → management'), findsOneWidget);
    expect(find.text('₱2,550.00'), findsOneWidget); // 3000 − 450
  });

  testWidgets('closed view: handoff rows from the frozen record; no drift '
      'section when nothing changed', (tester) async {
    final closing = _closing(DateTime(2026, 7, 24));
    await tester.pumpWidget(_harness(closing: closing));
    await tester.pump();
    await tester.pump();

    expect(find.text('Labor fees → mechanics'), findsOneWidget);
    expect(find.text('Sale items → management'), findsOneWidget);
    expect(find.text('₱1,550.00'), findsOneWidget); // 2000 − 450
    expect(find.text('After close'), findsNothing);
  });

  testWidgets('closed view: drift shows the shared AfterCloseCard with split',
      (tester) async {
    final closing = _closing(DateTime(2026, 7, 24));
    // One more cash labor-only sale (₱300) after close.
    await tester.pumpWidget(_harness(
      closing: closing,
      liveSummary: _summary(salesCount: 3, cash: 1750, labor: 750),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('After close'), findsOneWidget);
    expect(find.text('Sale items'), findsOneWidget);
    expect(find.text('Labor fees'), findsOneWidget);
    expect(find.text('Updated for management'), findsOneWidget);
    expect(find.text('For mechanics (whole day)'), findsOneWidget);
    expect(find.text('₱750.00'), findsOneWidget);
  });
}
