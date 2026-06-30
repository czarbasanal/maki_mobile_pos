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
        {String? reason}) =>
    PriceHistoryEntry(
      id: id,
      price: price,
      cost: cost,
      changedAt: at,
      changedBy: 'u1',
      reason: reason,
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

  testWidgets('single entry hides the sparkline with a caption', (tester) async {
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
}
