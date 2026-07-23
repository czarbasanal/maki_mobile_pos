import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/dashboard/dashboard_screen.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/quick_actions.dart';

void main() {
  // Cashier: renders the full dashboard without the admin-only
  // VoidRequestsBell (avoids overriding the void-request providers).
  UserEntity cashier() => UserEntity(
        id: 'u-1',
        email: 'c@x.com',
        displayName: 'Cash Ier',
        role: UserRole.cashier,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );

  const emptySummary = SalesSummary(
    totalSalesCount: 0,
    voidedSalesCount: 0,
    grossAmount: 0,
    totalDiscounts: 0,
    netAmount: 0,
    totalCost: 0,
    totalProfit: 0,
    byPaymentMethod: {},
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(cashier())),
          todaysSalesProvider
              .overrideWith((ref) => Stream.value(const <SaleEntity>[])),
          todaysSalesSummaryProvider.overrideWith((ref) async => emptySummary),
          monthToDateSummaryProvider.overrideWith((ref) async => emptySummary),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('date header and QuickActions scroll with the dashboard body',
      (tester) async {
    await pump(tester);

    // Both live INSIDE the CustomScrollView — not in a pinned container.
    expect(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(QuickActions),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byIcon(LucideIcons.calendar),
      ),
      findsOneWidget,
    );
    // Body is the refresh + scroll view directly.
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });
}
