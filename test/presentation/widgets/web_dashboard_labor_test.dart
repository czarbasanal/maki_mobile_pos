import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/inventory_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/web/screens/dashboard/web_dashboard_screen.dart';

SalesSummary _summary() => const SalesSummary(
      totalSalesCount: 1,
      voidedSalesCount: 0,
      grossAmount: 0,
      totalDiscounts: 0,
      netAmount: 0,
      totalCost: 0,
      totalProfit: 0,
      byPaymentMethod: {PaymentMethod.cash: 450},
      laborRevenue: 450,
      laborProfit: 450,
    );

void main() {
  testWidgets('web dashboard shows a Service revenue card', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        todaysSalesSummaryProvider.overrideWith((ref) async => _summary()),
        todaysSalesProvider.overrideWith((ref) => Stream.value(<SaleEntity>[])),
        inventorySummaryProvider.overrideWith(
          (ref) => AsyncValue.data(
            const InventorySummary(
              totalProducts: 0,
              inStockCount: 0,
              lowStockCount: 0,
              outOfStockCount: 0,
              totalValueAtCost: 0,
              totalValueAtPrice: 0,
            ),
          ),
        ),
      ],
      child: const MaterialApp(home: WebDashboardScreen()),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Service revenue'), findsOneWidget);
    expect(find.textContaining('450'), findsWidgets);
  });
}
