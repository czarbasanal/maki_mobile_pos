import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/price_change_report.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/price_change_report_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

void main() {
  List<ProductPriceChangeSummary> summaries() => priceChangeProductSummaries(
        [
          PriceChangeEntry(
            id: 'a',
            productId: 'p1',
            price: 150,
            cost: 80,
            changedAt: DateTime(2026, 6, 10),
            changedBy: 'u1',
            reason: 'Price update',
          ),
        ],
        {
          'p1': PriceHistoryEntry(
            id: 'b',
            price: 100,
            cost: 60,
            changedAt: DateTime(2026, 5, 1),
            changedBy: 'u1',
          ),
        },
      );

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        priceChangeSummariesProvider
            .overrideWith((ref, params) async => summaries()),
        productsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: const MaterialApp(home: PriceChangeReportScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('renders prev -> curr with diff for cost and SRP',
      (tester) async {
    await pumpScreen(tester);

    // Card shows both values of each metric plus the diff.
    expect(find.textContaining('₱100.00'), findsOneWidget); // prev SRP
    expect(find.textContaining('₱150.00'), findsOneWidget); // curr SRP
    expect(find.textContaining('₱60.00'), findsOneWidget); // prev cost
    expect(find.textContaining('₱80.00'), findsOneWidget); // curr cost
    expect(find.textContaining('₱50.00'), findsOneWidget); // SRP diff
    expect(find.textContaining('₱20.00'), findsOneWidget); // cost diff
    expect(find.textContaining('1 change'), findsOneWidget);
  });

  testWidgets('shows the sort filter with all four options', (tester) async {
    await pumpScreen(tester);

    final sortFilter = find.byKey(const Key('price-change-sort'));
    expect(sortFilter, findsOneWidget);
    for (final label in ['Latest', 'Cost', 'SRP', 'Both']) {
      expect(
        find.descendant(of: sortFilter, matching: find.text(label)),
        findsOneWidget,
      );
    }
  });
}
