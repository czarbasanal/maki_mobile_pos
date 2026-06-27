import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/sales_summary_card.dart';

UserEntity _user(UserRole role) => UserEntity(
      id: 'u1',
      email: 'u@test.com',
      displayName: 'User',
      role: role,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

SalesSummary _summary() => const SalesSummary(
      totalSalesCount: 17,
      voidedSalesCount: 1,
      grossAmount: 8640,
      totalDiscounts: 220,
      netAmount: 8420,
      totalCost: 4000,
      totalProfit: 4420,
      byPaymentMethod: {},
      laborRevenue: 0,
      laborProfit: 0,
    );

Widget _harness(UserRole role) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_user(role))),
        salesSummaryProvider.overrideWith((ref, params) async => _summary()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SalesSummaryCard(
            startDate: DateTime(2026, 6, 1),
            endDate: DateTime(2026, 6, 27),
          ),
        ),
      ),
    );

void main() {
  setUp(() {});

  testWidgets('cashier sees the lock note and no admin-only profit',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(UserRole.cashier));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Net Sales'), findsOneWidget);
    expect(
        find.text('Cost & profit are hidden for your role'), findsOneWidget);
    expect(find.byIcon(LucideIcons.lock), findsOneWidget);
    expect(find.text('Gross Profit'), findsNothing);
    expect(find.text('Total Cost'), findsNothing);
  });

  testWidgets('admin sees the Admin only divider and Gross Profit',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(UserRole.admin));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('ADMIN ONLY'), findsOneWidget);
    expect(find.text('Gross Profit'), findsOneWidget);
    expect(find.text('Total Cost'), findsOneWidget);
    expect(
        find.text('Cost & profit are hidden for your role'), findsNothing);
  });
}
