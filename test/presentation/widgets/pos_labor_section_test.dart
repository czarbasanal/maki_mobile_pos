import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/pos/pos_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/mechanic_picker.dart';

ProductEntity _product() => ProductEntity(
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

void main() {
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

  testWidgets('Labor & Service section appears with a mechanic picker',
      (tester) async {
    tester.view.physicalSize = const Size(3840, 2160);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(overrides: [
      activeMechanicsProvider.overrideWith(
        (ref) => Stream.value(<MechanicEntity>[]),
      ),
    ]);
    addTearDown(container.dispose);
    container.read(cartProvider.notifier).addProduct(_product());

    await tester.pumpWidget(host(container));
    // Use pump instead of pumpAndSettle to avoid halting on overflow errors.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Labor & Service'), findsOneWidget);

    // Expand the section; the mechanic picker + add affordance render.
    await tester.tap(find.text('Labor & Service'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MechanicPicker), findsOneWidget);
    expect(find.text('Add labor line'), findsOneWidget);
  });

  testWidgets('shows the labor validation banner when a mechanic is missing',
      (tester) async {
    tester.view.physicalSize = const Size(3840, 2160);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(overrides: [
      activeMechanicsProvider.overrideWith(
        (ref) => Stream.value([
          MechanicEntity(
            id: 'm1',
            name: 'Juan',
            isActive: true,
            createdAt: DateTime(2026, 1, 1),
          ),
        ]),
      ),
    ]);
    addTearDown(container.dispose);
    final cart = container.read(cartProvider.notifier);
    cart.addProduct(_product());
    cart.addLaborLine(description: 'Tune-up', fee: 450);

    await tester.pumpWidget(host(container));
    await tester.pump();
    // Section is auto-expanded (initiallyExpanded = true) because laborLines
    // are non-empty; no tap needed — tapping would collapse it instead.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Assign a mechanic'), findsOneWidget);
    // Save-as-Draft is gated off while labor is invalid.
    final saveButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Save as Draft'),
    );
    expect(saveButton.onPressed, isNull);
  });
}
