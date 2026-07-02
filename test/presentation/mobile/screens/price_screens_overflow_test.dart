// Regression: money rows on the price screens must not overflow on a narrow
// phone with 4-digit peso values (real inventory, e.g. exhaust pipes ₱7,500).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/price_change_report.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/inventory/price_history_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/price_change_report_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

void main() {
  Future<void> setNarrowPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('price-change report card with large values @320',
      (tester) async {
    await setNarrowPhone(tester);
    final s = priceChangeProductSummaries(
      [
        PriceChangeEntry(
          id: 'a',
          productId: 'p1',
          price: 7500,
          cost: 5200.50,
          changedAt: DateTime(2026, 6, 25),
          changedBy: 'u1',
          reason: 'Price update',
        ),
      ],
      {
        'p1': PriceHistoryEntry(
          id: 'b',
          price: 5781.29,
          cost: 4120.75,
          changedAt: DateTime(2026, 5, 1),
          changedBy: 'u1',
        ),
      },
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        priceChangeSummariesProvider.overrideWith(
            (ref, params) async => (summaries: s, truncated: false)),
        productsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: const MaterialApp(home: PriceChangeReportScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('price-history screen with large values @320',
      (tester) async {
    await setNarrowPhone(tester);
    final entries = [
      PriceHistoryEntry(
        id: 'a',
        price: 7500,
        cost: 5200.50,
        changedAt: DateTime(2026, 6, 25, 14, 30),
        changedBy: 'u1',
        reason: 'Stock receiving',
        note: 'Mock demo — RCV-20260625-0001',
      ),
      PriceHistoryEntry(
        id: 'b',
        price: 5781.29,
        cost: 4120.75,
        changedAt: DateTime(2026, 5, 1, 9, 5),
        changedBy: 'u1',
        reason: 'Price + cost update',
      ),
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        priceHistoryProvider.overrideWith((ref, id) async => entries),
        userByIdProvider.overrideWith((ref, id) async => null),
      ],
      child: const MaterialApp(home: PriceHistoryScreen(productId: 'p1')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });
}
