import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/daily_closing_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/daily_closing_history_screen.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

DailyClosingEntity _closing({
  required String id,
  required DateTime date,
  required double variance,
}) =>
    DailyClosingEntity(
      id: id,
      businessDate: date,
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
      openingFloat: 1000,
      expectedCash: 5770,
      countedCash: 5770 + variance,
      variance: variance,
      salesCount: 14,
      voidedCount: 0,
      closedBy: 'u1',
      closedByName: 'Maria Santos',
      closedAt: DateTime(2026, 6, 27, 18, 32),
    );

Widget _harness(List<DailyClosingEntity> closings) => ProviderScope(
      overrides: [
        closingHistoryInRangeProvider
            .overrideWith((ref, range) async => closings),
      ],
      child: const MaterialApp(home: DailyClosingHistoryScreen()),
    );

void main() {
  testWidgets('shows a red short pill and an amber over pill', (tester) async {
    await tester.pumpWidget(_harness([
      _closing(id: 'a', date: DateTime(2026, 6, 27), variance: -20),
      _closing(id: 'b', date: DateTime(2026, 6, 25), variance: 50),
    ]));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byIcon(LucideIcons.trendingDown), findsOneWidget);
    expect(find.byIcon(LucideIcons.trendingUp), findsOneWidget);
  });

  testWidgets('tapping a row expands its reconciliation', (tester) async {
    await tester.pumpWidget(_harness([
      _closing(id: 'a', date: DateTime(2026, 6, 27), variance: -20),
    ]));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Expected cash'), findsNothing);
    // Scoped to the list: the range picker's pills carry chevrons too.
    await tester.tap(find
        .descendant(
          of: find.byType(ListView),
          matching: find.byIcon(LucideIcons.chevronDown),
        )
        .first);
    await tester.pumpAndSettle();
    expect(find.text('Expected cash'), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await tester.pumpWidget(_harness([]));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('No closings yet'), findsOneWidget);
  });

  testWidgets('defaults to this month', (tester) async {
    await tester.pumpWidget(_harness([
      _closing(id: 'a', date: DateTime(2026, 8, 30), variance: 0),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('This Month'), findsOneWidget);
  });

  testWidgets('shows ten rows and offers the rest behind Load more',
      (tester) async {
    // A month of closings is more than anyone reads at once, and every row
    // expands into a long block.
    final many = List.generate(
      23,
      (i) => _closing(
          id: 'c$i', date: DateTime(2026, 8, i + 1), variance: 0),
    );
    await tester.pumpWidget(_harness(many));
    await tester.pumpAndSettle();

    // Row widgets cannot be counted — ListView.builder only builds what fits
    // the viewport. The button's own label is the assertion: 13 left of 23
    // means 10 are in the list.
    await tester.scrollUntilVisible(find.textContaining('Load more'), 300);
    expect(find.text('Load more (13 left)'), findsOneWidget);

    await tester.tap(find.text('Load more (13 left)'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('Load more'), 300);
    expect(find.text('Load more (3 left)'), findsOneWidget);
  });

  testWidgets('changing the range resets paging to the first ten',
      (tester) async {
    final many = List.generate(
      23,
      (i) => _closing(
          id: 'c$i', date: DateTime(2026, 8, i + 1), variance: 0),
    );
    await tester.pumpWidget(_harness(many));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('Load more'), 300);
    await tester.tap(find.text('Load more (13 left)'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('This Month'), -300);
    await tester.tap(find.text('This Month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today').last);
    await tester.pumpAndSettle();

    // Back to a single page for the new range.
    await tester.scrollUntilVisible(find.textContaining('Load more'), 300);
    expect(find.text('Load more (13 left)'), findsOneWidget);
  });

  testWidgets('the CSV export is disabled when the range holds nothing',
      (tester) async {
    await tester.pumpWidget(_harness([]));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<IconButton>(
              find.widgetWithIcon(IconButton, LucideIcons.download))
          .onPressed,
      isNull,
    );
  });

  testWidgets('the CSV export is offered once the range has closings',
      (tester) async {
    await tester.pumpWidget(_harness([
      _closing(id: 'a', date: DateTime(2026, 8, 30), variance: 0),
    ]));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<IconButton>(
              find.widgetWithIcon(IconButton, LucideIcons.download))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('the image export is reachable only from an open day',
      (tester) async {
    // Per day by construction: the action lives inside the expanded detail,
    // so there is no way to ask for a range as one image.
    await tester.pumpWidget(_harness([
      _closing(id: 'a', date: DateTime(2026, 8, 30), variance: 0),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Save as image'), findsNothing);

    await tester.tap(find
        .descendant(
          of: find.byType(ListView),
          matching: find.byIcon(LucideIcons.chevronDown),
        )
        .first);
    await tester.pumpAndSettle();
    expect(find.text('Save as image'), findsOneWidget);
  });

  testWidgets('the save button is not inside the captured boundary',
      (tester) async {
    // A saved receipt must not have a Save button printed on it.
    await tester.pumpWidget(_harness([
      _closing(id: 'a', date: DateTime(2026, 8, 30), variance: 0),
    ]));
    await tester.pumpAndSettle();
    await tester.tap(find
        .descendant(
          of: find.byType(ListView),
          matching: find.byIcon(LucideIcons.chevronDown),
        )
        .first);
    await tester.pumpAndSettle();

    // Scoped to the captured subtree — Flutter's tree is full of unrelated
    // RepaintBoundaries, so asserting against the type would always pass.
    expect(find.byKey(const ValueKey('closing-detail')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('closing-detail')),
        matching: find.text('Save as image'),
      ),
      findsNothing,
    );
  });
}
