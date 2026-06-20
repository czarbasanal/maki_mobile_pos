import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/sales_summary_section.dart';

void main() {
  Widget host(SalesSummary summary) => ProviderScope(
        overrides: [
          todaysSalesSummaryProvider.overrideWith((ref) async => summary),
          avgDailySalesProvider.overrideWith((ref) => const AsyncData(0.0)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SalesSummarySection(isAdmin: true),
            ),
          ),
        ),
      );

  const withLabor = SalesSummary(
    totalSalesCount: 1,
    voidedSalesCount: 0,
    grossAmount: 1000,
    totalDiscounts: 0,
    netAmount: 1000,
    totalCost: 600,
    totalProfit: 400,
    byPaymentMethod: {PaymentMethod.cash: 1450},
    laborRevenue: 450,
    laborProfit: 450,
  );

  const noLabor = SalesSummary(
    totalSalesCount: 1,
    voidedSalesCount: 0,
    grossAmount: 1000,
    totalDiscounts: 0,
    netAmount: 1000,
    totalCost: 600,
    totalProfit: 400,
    byPaymentMethod: {PaymentMethod.cash: 1000},
  );

  testWidgets('shows Service / Labor card when laborRevenue > 0',
      (tester) async {
    await tester.pumpWidget(host(withLabor));
    await tester.pumpAndSettle();

    expect(find.text('Service / Labor'), findsOneWidget);
    // Parts cards still present and parts-only.
    expect(find.text('Profit'), findsOneWidget);
    expect(find.text('COGS'), findsOneWidget);
  });

  testWidgets('hides Service / Labor card when no labor', (tester) async {
    await tester.pumpWidget(host(noLabor));
    await tester.pumpAndSettle();

    expect(find.text('Service / Labor'), findsNothing);
    expect(find.text('Profit'), findsOneWidget);
  });
}
