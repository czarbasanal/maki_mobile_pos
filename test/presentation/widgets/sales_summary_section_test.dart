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
  required bool isAdmin,
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
          body: SalesSummarySection(isAdmin: isAdmin),
        ),
      ),
    ),
  );
}

void main() {
  group('SalesSummarySection', () {
    testWidgets('non-admin sees Gross Sales only — no admin-only metrics',
        (tester) async {
      await _pump(
        tester,
        isAdmin: false,
        summary: _summary(gross: 5000),
        avgDaily: const AsyncValue.data(3000),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gross Sales'), findsOneWidget);
      expect(find.text('Avg Daily'), findsNothing);
      expect(find.text('COGS'), findsNothing);
      expect(find.text('Profit'), findsNothing);
    });

    testWidgets('admin sees the hero plus supporting stat cards',
        (tester) async {
      await _pump(
        tester,
        isAdmin: true,
        summary: _summary(),
        avgDaily: const AsyncValue.data(1500),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gross Sales'), findsOneWidget);
      expect(find.text('Avg Daily'), findsOneWidget);
      expect(find.text('COGS'), findsOneWidget);
      expect(find.text('Profit'), findsOneWidget);
    });

    testWidgets('Gross Sales reflects grossAmount, not netAmount',
        (tester) async {
      await _pump(
        tester,
        isAdmin: false,
        summary: _summary(gross: 5000, net: 4500, discounts: 500),
        avgDaily: const AsyncValue.data(0),
      );
      await tester.pumpAndSettle();

      // 5000 → the hero shows ₱5,000 with the centavos (.00) rendered
      // smaller/muted beside it (two Text widgets), never the net amount.
      expect(find.text('₱5,000'), findsOneWidget);
      expect(find.text('.00'), findsOneWidget);
      expect(find.textContaining('4,500'), findsNothing);
      // The discount subtitle should be present.
      expect(find.textContaining('discount'), findsOneWidget);
    });

    testWidgets('Avg Daily Sales shows dash while loading (admin)',
        (tester) async {
      await _pump(
        tester,
        isAdmin: true,
        summary: _summary(),
        avgDaily: const AsyncValue.loading(),
      );
      await tester.pumpAndSettle();

      // The avg-daily card shows a dash placeholder.
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('COGS stat reflects summary.totalCost (compact)',
        (tester) async {
      await _pump(
        tester,
        isAdmin: true,
        summary: _summary(cost: 7100),
        avgDaily: const AsyncValue.data(0),
      );
      await tester.pumpAndSettle();

      // Supporting stat cards use the compact ₱K/M format.
      expect(find.text('₱7.1K'), findsOneWidget);
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
              body: SalesSummarySection(isAdmin: false),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
