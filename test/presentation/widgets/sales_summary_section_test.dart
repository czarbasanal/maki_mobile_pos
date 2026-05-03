import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/sales_summary_section.dart';

SalesSummary _summary({
  double gross = 5000,
  double net = 4500,
  double discounts = 500,
  double cost = 2000,
  double profit = 2500,
  int salesCount = 10,
}) {
  return SalesSummary(
    totalSalesCount: salesCount,
    voidedSalesCount: 0,
    grossAmount: gross,
    totalDiscounts: discounts,
    netAmount: net,
    totalCost: cost,
    totalProfit: profit,
    byPaymentMethod: const {},
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required bool showProfit,
  required SalesSummary summary,
  required AsyncValue<double> avgDaily,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        todaysSalesSummaryProvider.overrideWith((ref) async => summary),
        avgDailySalesProvider.overrideWith((ref) => avgDaily),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SalesSummarySection(showProfit: showProfit),
        ),
      ),
    ),
  );
}

void main() {
  group('SalesSummarySection', () {
    testWidgets('non-admin sees Gross Sales and Avg Daily Sales only',
        (tester) async {
      await _pump(
        tester,
        showProfit: false,
        summary: _summary(gross: 5000),
        avgDaily: const AsyncValue.data(3000),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gross Sales'), findsOneWidget);
      expect(find.text('Avg Daily Sales'), findsOneWidget);
      expect(find.text('Total COGS'), findsNothing);
      expect(find.text('Gross Profit'), findsNothing);
    });

    testWidgets('admin sees all four cards', (tester) async {
      await _pump(
        tester,
        showProfit: true,
        summary: _summary(),
        avgDaily: const AsyncValue.data(1500),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gross Sales'), findsOneWidget);
      expect(find.text('Avg Daily Sales'), findsOneWidget);
      expect(find.text('Total COGS'), findsOneWidget);
      expect(find.text('Gross Profit'), findsOneWidget);
    });

    testWidgets('Gross Sales reflects grossAmount, not netAmount',
        (tester) async {
      await _pump(
        tester,
        showProfit: false,
        summary: _summary(gross: 5000, net: 4500, discounts: 500),
        avgDaily: const AsyncValue.data(0),
      );
      await tester.pumpAndSettle();

      // 5000 → ₱5.0K via the K-suffix formatter.
      expect(find.text('₱5.0K'), findsOneWidget);
      // The discount subtitle should be present.
      expect(find.textContaining('discount'), findsOneWidget);
    });

    testWidgets('Avg Daily Sales shows dash while loading', (tester) async {
      await _pump(
        tester,
        showProfit: false,
        summary: _summary(),
        avgDaily: const AsyncValue.loading(),
      );
      await tester.pumpAndSettle();

      // The avg-daily card shows a dash placeholder.
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('Total COGS reflects summary.totalCost', (tester) async {
      // Use a sub-1000 value so the formatter doesn't apply the K suffix.
      await _pump(
        tester,
        showProfit: true,
        summary: _summary(cost: 234.56),
        avgDaily: const AsyncValue.data(0),
      );
      await tester.pumpAndSettle();

      expect(find.text('₱234.56'), findsOneWidget);
    });

    testWidgets('shows a spinner while today summary loads', (tester) async {
      // A Completer that is never completed keeps the FutureProvider in
      // the loading state without leaving any pending Timer behind for
      // the test harness to complain about.
      final completer = Completer<SalesSummary>();
      addTearDown(() {
        if (!completer.isCompleted) completer.complete(_summary());
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todaysSalesSummaryProvider.overrideWith((ref) => completer.future),
            avgDailySalesProvider
                .overrideWith((ref) => const AsyncValue.data(0)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SalesSummarySection(showProfit: false),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
