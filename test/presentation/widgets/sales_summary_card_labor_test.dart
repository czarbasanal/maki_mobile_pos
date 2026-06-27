import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/sales_summary_card.dart';

UserEntity _adminUser() => UserEntity(
      id: 'u1',
      email: 'admin@test.com',
      displayName: 'Admin',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

SalesSummary _laborSummary() => const SalesSummary(
      totalSalesCount: 1,
      voidedSalesCount: 0,
      grossAmount: 1000,
      totalDiscounts: 0,
      netAmount: 1000,
      totalCost: 500,
      totalProfit: 500,
      byPaymentMethod: {},
      laborRevenue: 450,
      laborProfit: 450,
    );

void main() {
  final start = DateTime(2026, 5, 1);
  final end = DateTime(2026, 5, 31);

  testWidgets(
      'SalesSummaryCard admin view shows Service Revenue and Service Profit rows',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith(
          (ref) => Stream.value(_adminUser()),
        ),
        salesSummaryProvider.overrideWith(
          (ref, params) async => _laborSummary(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SalesSummaryCard(startDate: start, endDate: end),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Service Rev.'), findsOneWidget);
    expect(find.text('Service Profit'), findsOneWidget);
    // The formatted value ₱450.00 should appear.
    expect(find.textContaining('450'), findsWidgets);
  });
}
