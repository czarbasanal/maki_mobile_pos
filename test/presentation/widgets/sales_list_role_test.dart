import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/sales_list_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/reports_widgets.dart';

UserEntity _user(UserRole role) => UserEntity(
      id: 'u1',
      email: 'u@test.com',
      displayName: 'User',
      role: role,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

SaleEntity _sale() => SaleEntity(
      id: 's1',
      saleNumber: 'SALE-20260627-1',
      items: const [
        SaleItemEntity(
          id: 'p1-line',
          productId: 'p1',
          sku: 'SKU',
          name: 'Item',
          unitPrice: 100,
          unitCost: 60,
          quantity: 1,
        ),
      ],
      paymentMethod: PaymentMethod.cash,
      amountReceived: 100,
      changeGiven: 0,
      status: SaleStatus.completed,
      cashierId: 'u1',
      cashierName: 'Maria',
      createdAt: DateTime(2026, 6, 27, 10),
    );

Widget _harness(UserRole role) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_user(role))),
        salesByDateRangeProvider
            .overrideWith((ref, params) async => [_sale()]),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, __) => const SalesListScreen()),
          ],
        ),
      ),
    );

void main() {
  testWidgets('daily-only role shows the forced-today banner + lock footer',
      (tester) async {
    await tester.pumpWidget(_harness(UserRole.cashier));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text("Showing today's sales only"), findsOneWidget);
    expect(find.text('Earlier days are not available for your role'),
        findsOneWidget);
    expect(find.byType(DateRangePicker), findsNothing);
  });

  testWidgets('admin role shows the DateRangePicker, no banner',
      (tester) async {
    await tester.pumpWidget(_harness(UserRole.admin));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(DateRangePicker), findsOneWidget);
    expect(find.text("Showing today's sales only"), findsNothing);
  });
}
