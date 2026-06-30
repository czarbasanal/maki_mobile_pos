import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/daily_closing_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/daily_closing_history_screen.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';

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
        dailyClosingHistoryProvider
            .overrideWith((ref) => Stream.value(closings)),
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
    await tester.tap(find.byIcon(LucideIcons.chevronDown));
    await tester.pumpAndSettle();
    expect(find.text('Expected cash'), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await tester.pumpWidget(_harness([]));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('No closings yet'), findsOneWidget);
  });
}
