import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/price_change_report.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/price_change_report_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

void main() {
  testWidgets('renders price-change rows from the provider', (tester) async {
    final rows = priceChangeRowsInRange([
      PriceChangeEntry(
        id: 'a',
        productId: 'p1',
        price: 120,
        cost: 70,
        changedAt: DateTime(2026, 6, 10),
        changedBy: 'u1',
        reason: 'receiving',
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        priceChangeReportProvider.overrideWith((ref, params) async => rows),
        productsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: const MaterialApp(home: PriceChangeReportScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('receiving'), findsWidgets);
  });
}
