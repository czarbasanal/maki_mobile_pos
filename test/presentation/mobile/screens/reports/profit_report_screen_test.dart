import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/profit_report_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

SalesSummary _summary() => const SalesSummary(
      totalSalesCount: 4,
      voidedSalesCount: 0,
      grossAmount: 1000,
      totalDiscounts: 0,
      netAmount: 1000,
      totalCost: 400,
      totalProfit: 600,
      byPaymentMethod: {},
      laborRevenue: 150,
      laborProfit: 150,
    );

void main() {
  testWidgets('wires summary + profit-by-product from providers',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        profitReportProvider.overrideWith((ref, params) async => _summary()),
        topSellingProductsProvider.overrideWith((ref, params) async => const [
              ProductSalesData(
                productId: 'p1',
                sku: 'SKU-1',
                name: 'Brake Pad',
                quantitySold: 3,
                totalRevenue: 300,
                totalCost: 120,
              ),
            ]),
      ],
      child: const MaterialApp(home: ProfitReportScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Total Revenue'), findsOneWidget);
    expect(find.text('Gross Profit'), findsOneWidget);
    expect(find.text('Profit Margin'), findsOneWidget);
    // Labor profit card appears because laborProfit > 0.
    expect(find.text('Service / Labor Profit (tracked separately)'),
        findsOneWidget);
    // Profit-by-product row.
    expect(find.text('Brake Pad'), findsOneWidget);
  });
}
