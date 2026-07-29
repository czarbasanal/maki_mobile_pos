import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
  double laborRevenue = 0,
  double laborProfit = 0,
  double feesRevenue = 0,
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
    laborRevenue: laborRevenue,
    laborProfit: laborProfit,
    feesRevenue: feesRevenue,
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

    testWidgets('labor and shop fees share one row when both are present',
        (tester) async {
      await _pump(
        tester,
        isAdmin: true,
        summary: _summary(
          laborRevenue: 800,
          laborProfit: 800,
          feesRevenue: 150,
        ),
        avgDaily: const AsyncValue.data(0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Service / Labor'), findsOneWidget);
      expect(find.text('Shop Fees'), findsOneWidget);

      // Same row = same vertical centre, side by side.
      final labor = tester.getRect(find.text('Service / Labor'));
      final fees = tester.getRect(find.text('Shop Fees'));
      expect(labor.center.dy, moreOrLessEquals(fees.center.dy, epsilon: 1));
      expect(labor.center.dx, lessThan(fees.center.dx));
    });

    testWidgets('labor alone still spans the full width', (tester) async {
      await _pump(
        tester,
        isAdmin: true,
        summary: _summary(laborRevenue: 800, laborProfit: 800),
        avgDaily: const AsyncValue.data(0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Service / Labor'), findsOneWidget);
      expect(find.text('Shop Fees'), findsNothing);
    });

    testWidgets('shop fees alone still renders', (tester) async {
      await _pump(
        tester,
        isAdmin: true,
        summary: _summary(feesRevenue: 150),
        avgDaily: const AsyncValue.data(0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shop Fees'), findsOneWidget);
      expect(find.text('Service / Labor'), findsNothing);
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

  group('Avg Daily info button', () {
    Future<void> pump(WidgetTester tester, {required double? avgDaily}) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          todaysSalesSummaryProvider
              .overrideWith((ref) async => SalesSummary.empty()),
          avgDailySalesProvider.overrideWithValue(AsyncValue.data(avgDaily)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SalesSummarySection(isAdmin: true),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('shows a dash when there is no completed day yet',
        (tester) async {
      await pump(tester, avgDaily: null);
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('exactly one info button — on the Avg Daily card',
        (tester) async {
      await pump(tester, avgDaily: 1234);
      expect(find.byIcon(LucideIcons.info), findsOneWidget);

      // Scope to the card subtree that actually contains the "Avg Daily"
      // label — each stat card is wrapped in its own `Expanded` inside the
      // stat row, so this isolates just that one card (not COGS, not
      // Profit, not the whole row). A findsOneWidget on the icon alone
      // would still pass if the ⓘ were wired onto a different card; this
      // pins it to the right one.
      //
      // We scope on `Expanded` (rather than the card widget itself)
      // because `_StatCard` is private to sales_summary_section.dart and
      // can't be named from this test file. If a future refactor swaps
      // the per-card wrapper to e.g. `Flexible`, this finder will start
      // failing empty rather than silently passing vacuous again — update
      // the matched type here to match.
      final avgDailyCard = find.ancestor(
        of: find.text('Avg Daily'),
        matching: find.byType(Expanded),
      );
      expect(avgDailyCard, findsOneWidget);
      expect(
        find.descendant(
          of: avgDailyCard,
          matching: find.byIcon(LucideIcons.info),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping the info button explains the completed-days rule',
        (tester) async {
      await pump(tester, avgDaily: 1234);

      // Tap the ⓘ scoped to the Avg Daily card's subtree specifically —
      // if the info button were wired onto COGS or Profit instead, this
      // finder comes up empty and the tap fails, rather than silently
      // hitting whichever single ⓘ happens to exist anywhere in the tree.
      final avgDailyCard = find.ancestor(
        of: find.text('Avg Daily'),
        matching: find.byType(Expanded),
      );
      await tester.tap(find.descendant(
        of: avgDailyCard,
        matching: find.byIcon(LucideIcons.info),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Your average sales per day this month, counting only days that '
          'have finished.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          "It adds up sales from the 1st up to yesterday, then divides by that "
          "many days. Today isn't counted yet because it's still going.",
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'the tap target is genuinely enlarged, not just painted larger',
        (tester) async {
      await pump(tester, avgDaily: 1234);

      final avgDailyCard = find.ancestor(
        of: find.text('Avg Daily'),
        matching: find.byType(Expanded),
      );

      // The glyph itself is the one thing the design requires to stay
      // fixed (14px, same on-screen spot) regardless of how big the tap
      // region is — so, unlike the hit region's own Rect, it's a stable
      // anchor to derive an exclusion zone from, not something whose size
      // is literally what this test is trying to verify. `inflate(2)`
      // reconstructs the old box exactly: the pre-fix implementation was
      // `Padding(all: 2)` directly around this same 14px icon, i.e. an
      // 18x18 box centred on the glyph.
      final iconRect = tester.getRect(find.descendant(
        of: avgDailyCard,
        matching: find.byIcon(LucideIcons.info),
      ));
      final oldBoxBounds = iconRect.inflate(2);

      final hitRegion = find.descendant(
        of: avgDailyCard,
        matching: find.byType(InkWell),
      );
      expect(hitRegion, findsOneWidget);
      final hitRect = tester.getRect(hitRegion);

      // A corner of the *current* hit region, well away from the glyph.
      final farCorner = Offset(hitRect.left + 2, hitRect.bottom - 2);

      // Self-check: this point only proves anything if it actually falls
      // outside where the old, genuinely-small box used to be. If the hit
      // region has regressed back to ~18x18 (or a fix like OverflowBox
      // only *paints* larger without truly reporting a bigger size to
      // hit-testing), `hitRect` collapses back toward `oldBoxBounds` and
      // this point ends up inside it too — failing here, honestly, rather
      // than at an unrelated-looking "dialog didn't open" assertion below.
      expect(
        oldBoxBounds.contains(farCorner),
        isFalse,
        reason: 'chosen tap point $farCorner must sit outside the old '
            '~18x18 box $oldBoxBounds for this test to prove the hit '
            'region is genuinely larger, not just painted larger',
      );

      await tester.tapAt(farCorner);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Your average sales per day this month, counting only days that '
          'have finished.',
        ),
        findsOneWidget,
      );
    });
  });
}
