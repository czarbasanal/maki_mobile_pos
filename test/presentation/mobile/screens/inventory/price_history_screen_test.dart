import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart'
    show PriceHistoryEntry;
import 'package:maki_mobile_pos/presentation/mobile/screens/inventory/price_history_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/user_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';

PriceHistoryEntry _e(String id, double price, double cost, DateTime at,
        {String? reason,
        String? optionId,
        String? optionLabel,
        int? optionPieces}) =>
    PriceHistoryEntry(
      id: id,
      price: price,
      cost: cost,
      changedAt: at,
      changedBy: 'u1',
      reason: reason,
      optionId: optionId,
      optionLabel: optionLabel,
      optionPieces: optionPieces,
    );

PriceHistoryEntry _o(
  String id,
  double price,
  DateTime at, {
  required String optionId,
  required String optionLabel,
  required int optionPieces,
}) =>
    PriceHistoryEntry(
      id: id,
      price: price,
      cost: 180,
      changedAt: at,
      changedBy: 'u1',
      reason: 'Price update',
      optionId: optionId,
      optionLabel: optionLabel,
      optionPieces: optionPieces,
    );

final _actor = UserEntity(
  id: 'u1',
  email: 'a@test',
  displayName: 'Alice Admin',
  role: UserRole.admin,
  isActive: true,
  createdAt: DateTime(2024, 1, 1),
);

Future<void> _pump(
  WidgetTester tester,
  List<PriceHistoryEntry> entries,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        priceHistoryProvider('p-1').overrideWith((ref) async => entries),
        userByIdProvider('u1').overrideWith((ref) async => _actor),
      ],
      child: const MaterialApp(
        home: PriceHistoryScreen(productId: 'p-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows empty state when there is no history', (tester) async {
    await _pump(tester, const []);
    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('No price changes yet'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('single entry hides the sparkline with a caption',
      (tester) async {
    await _pump(tester,
        [_e('e1', 100, 60, DateTime(2026, 1, 1), reason: 'Initial price')]);
    expect(find.text('Not enough changes to chart'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('Created'), findsOneWidget); // source label
  });

  testWidgets('multiple entries render sparkline, filter, and rows',
      (tester) async {
    await _pump(tester, [
      _e('e2', 120, 70, DateTime(2026, 2, 1), reason: 'Price update'),
      _e('e1', 100, 60, DateTime(2026, 1, 1), reason: 'Initial price'),
    ]);
    expect(find.byType(LineChart), findsWidgets);
    expect(find.byKey(const Key('metric-filter')), findsOneWidget);
    expect(find.text('Alice Admin'), findsWidgets);

    // Switch to the Cost filter — tap the segment by key (the label 'Cost'
    // also appears on the sparkline trend header).
    await tester.tap(find.byKey(const Key('metric-seg-cost')));
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsWidgets);
  });

  testWidgets('sparkline + rows sit on AppCards with from→to trend labels',
      (tester) async {
    await _pump(tester, [
      _e('e3', 250, 180, DateTime(2026, 6, 18), reason: 'Price + cost update'),
      _e('e2', 230, 170, DateTime(2026, 5, 30), reason: 'Price update'),
      _e('e1', 225, 170, DateTime(2026, 5, 12), reason: 'Initial price'),
    ]);
    // Sparkline card + changes card are AppCard surfaces.
    expect(find.byType(AppCard), findsWidgets);
    // Two-part trend header carries the from→to range.
    expect(find.textContaining('→'), findsWidgets);
    expect(find.text('CHANGES'), findsOneWidget);
  });

  group('selling-option series', () {
    final baseOnly = [
      _e('e2', 130, 60, DateTime(2026, 7, 2)),
      _e('e1', 120, 60, DateTime(2026, 7, 1)),
    ];
    final mixed = [
      _o('o-e2', 360, DateTime(2026, 7, 3),
          optionId: 'o2', optionLabel: 'By 3', optionPieces: 3),
      _e('e2', 130, 60, DateTime(2026, 7, 2)),
      _o('o-e1', 330, DateTime(2026, 7, 1),
          optionId: 'o2', optionLabel: 'By 3', optionPieces: 3),
    ];

    testWidgets('renders no selector when there is only a base series',
        (tester) async {
      await _pump(tester, baseOnly);
      expect(find.byKey(const Key('series-selector')), findsNothing);
      expect(find.text('Base price'), findsNothing);
      expect(find.text('By 3'), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('renders a chip per series when options are present',
        (tester) async {
      await _pump(tester, mixed);
      expect(find.byKey(const Key('series-selector')), findsOneWidget);
      expect(find.text('Base price'), findsOneWidget);
      expect(find.text('By 3'), findsOneWidget);
      expect(find.byType(FilterChip), findsNWidgets(2));
    });

    testWidgets('defaults to the base series', (tester) async {
      await _pump(tester, mixed);
      // The base series in `mixed` has a single entry (₱130). Nothing from
      // the option series (₱360 / ₱330) should be on screen yet.
      expect(find.text('₱130'), findsWidgets);
      expect(find.text('₱360'), findsNothing);
      expect(find.text('₱330'), findsNothing);
    });

    testWidgets('selecting an option shows that series and not the base',
        (tester) async {
      await _pump(tester, mixed);
      await tester.tap(find.text('By 3'));
      await tester.pumpAndSettle();
      expect(find.text('₱360'), findsWidgets);
      expect(find.text('₱330'), findsWidgets);
      expect(find.text('₱130'), findsNothing);
    });

    testWidgets(
        'the option series delta is the option-to-option jump (₱30), not a '
        'base-to-option jump', (tester) async {
      await _pump(tester, mixed);
      await tester.tap(find.text('By 3'));
      await tester.pumpAndSettle();
      // ₱30 = 360 - 330, the two option entries. A wrong implementation that
      // fails to split series first would interleave the base (₱130) entry
      // in between and compute ₱230 (360-130) and ₱200 (130-330) instead.
      // Assert exact rendered strings, not substrings: '330' itself contains
      // '30', so a `textContaining('30')` check would pass no matter which
      // delta was actually computed and would prove nothing.
      expect(find.text('₱30'), findsOneWidget);
      expect(find.text('₱230'), findsNothing);
      expect(find.text('₱200'), findsNothing);
    });

    testWidgets('the chart plots only the selected series values',
        (tester) async {
      await _pump(tester, mixed);
      await tester.tap(find.text('By 3'));
      await tester.pumpAndSettle();
      // Metric defaults to All, so both a price and a cost sparkline render;
      // the price chart is the first LineChart in the tree.
      final priceChart =
          tester.widgetList<LineChart>(find.byType(LineChart)).first;
      final spots = priceChart.data.lineBarsData.first.spots;
      expect(spots.map((s) => s.y).toList(), [330.0, 360.0]);
    });
  });
}
