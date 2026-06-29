import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/daily_closing_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/end_of_day_screen.dart';

DailyClosingEntity _closing(DateTime d) => DailyClosingEntity(
      id: 'd1',
      businessDate: d,
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
      laborRevenue: 650,
      openingFloat: 1000,
      expectedCash: 5770,
      countedCash: 5750,
      variance: -20,
      salesCount: 14,
      voidedCount: 0,
      closedBy: 'u1',
      closedByName: 'Maria Santos',
      closedAt: DateTime(2026, 6, 27, 18, 32),
    );

// A live draft with two more sales (+₱1,300 gross, +₱800 cash) than the
// snapshot → triggers the post-close warning + After-close card.
DailyClosingDraft _draft(DateTime d) => DailyClosingDraft(
      businessDate: d,
      grossSales: 9720,
      netSales: 9600,
      totalDiscounts: 120,
      cashSales: 6000,
      nonCashSales: 3520,
      gcashSales: 2540,
      mayaSales: 980,
      totalExpenses: 430,
      cashExpenses: 430,
      salmonReceivable: 0,
      laborRevenue: 650,
      salesCount: 16,
      voidedCount: 0,
    );

void main() {
  final now = DateTime.now();
  final dayStart = DateTime(now.year, now.month, now.day);

  Widget harness() => ProviderScope(
        overrides: [
          dailyClosingForDateProvider
              .overrideWith((ref, date) async => _closing(dayStart)),
          dailyClosingDraftProvider
              .overrideWith((ref, date) async => _draft(dayStart)),
        ],
        child: const MaterialApp(home: EndOfDayScreen()),
      );

  testWidgets(
      'closed view shows closed-by banner, post-close warning, and After close',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.badgeCheck), findsOneWidget);
    expect(find.textContaining('Closed by Maria Santos'), findsOneWidget);
    expect(find.byIcon(LucideIcons.alertTriangle), findsOneWidget);
    expect(find.text('After close'), findsOneWidget);
    expect(find.text('Updated cash on hand'), findsOneWidget);
    expect(find.text('Close Day'), findsNothing);
  });
}
