import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/unsettled_day_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/pos/pos_screen.dart';

/// The checkout button's billable-content gate (`canProceedToCheckout`) is
/// covered elsewhere. This file proves the additional rollover gate added
/// on top of it: checkout is blocked while an earlier business day sits
/// unsettled, and unblocked once it's null again — mirroring how
/// `canProceedToCheckout` is already consumed in `_buildActionButtons`.
void main() {
  ProductEntity product() => ProductEntity(
        id: 'p1',
        sku: 'SKU-1',
        name: 'Spark Plug',
        costCode: 'AAA',
        cost: 60,
        price: 100,
        quantity: 10,
        reorderLevel: 0,
        unit: 'pcs',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );

  Widget host(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: RoutePaths.pos,
          routes: [
            GoRoute(
              path: RoutePaths.pos,
              builder: (_, __) => const POSScreen(),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('Checkout is disabled while an earlier day is unsettled',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(overrides: [
      activeMechanicsProvider.overrideWith((ref) => Stream.value(const [])),
      unsettledBusinessDayProvider
          .overrideWith((ref) async => DateTime(2026, 7, 20)),
    ]);
    addTearDown(container.dispose);
    container.read(cartProvider.notifier).addProduct(product());

    await tester.pumpWidget(host(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // FilledButton.icon builds a private FilledButton subtype, so
    // find.byType (exact runtimeType match) can't see it — match by `is`
    // instead via a predicate.
    final checkout = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Checkout'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(checkout.onPressed, isNull);
  });

  testWidgets('Checkout is enabled once nothing is unsettled', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(overrides: [
      activeMechanicsProvider.overrideWith((ref) => Stream.value(const [])),
      unsettledBusinessDayProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);
    container.read(cartProvider.notifier).addProduct(product());

    await tester.pumpWidget(host(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // FilledButton.icon builds a private FilledButton subtype, so
    // find.byType (exact runtimeType match) can't see it — match by `is`
    // instead via a predicate.
    final checkout = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Checkout'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(checkout.onPressed, isNotNull);
  });
}
