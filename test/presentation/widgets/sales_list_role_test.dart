import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/business_day_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/sales_list_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/reports_widgets.dart';

/// A [businessDayProvider] override that can be flipped mid-test, without
/// waiting on a real [Timer] or the wall clock.
class _FixedBusinessDayNotifier extends BusinessDayNotifier {
  _FixedBusinessDayNotifier(this._initial);
  final DateTime _initial;

  @override
  DateTime build() => _initial;

  void set(DateTime day) => state = day;
}

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

  testWidgets('sale number renders in RobotoMono', (tester) async {
    await tester.pumpWidget(_harness(UserRole.admin));
    await tester.pump(const Duration(seconds: 1));

    final noText = tester.widget<Text>(find.text('SALE-20260627-1'));
    expect(noText.style?.fontFamily, 'RobotoMono');
  });

  testWidgets(
      'daily-only forced range follows businessDayProvider and flips on '
      'a midnight rollover', (tester) async {
    final captured = <DateRangeParams>[];
    final dayNotifier = _FixedBusinessDayNotifier(DateTime(2026, 7, 24));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_user(UserRole.cashier))),
        businessDayProvider.overrideWith(() => dayNotifier),
        salesByDateRangeProvider.overrideWith((ref, params) async {
          captured.add(params);
          return <SaleEntity>[];
        }),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, __) => const SalesListScreen()),
          ],
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(captured.last.startDate, DateTime(2026, 7, 24));
    expect(captured.last.endDate, DateTime(2026, 7, 24, 23, 59, 59));

    dayNotifier.set(DateTime(2026, 7, 25));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(captured.last.startDate, DateTime(2026, 7, 25),
        reason: 'forced range must follow businessDayProvider, not stay '
            'pinned to the day the screen first opened on');
    expect(captured.last.endDate, DateTime(2026, 7, 25, 23, 59, 59));
  });
}
