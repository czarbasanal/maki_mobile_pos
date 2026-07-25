import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/shop_fee_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/fee_section.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/fee_line_row.dart';

ShopFeeEntity _shopFee({
  required String id,
  required String name,
  double? defaultAmount,
}) {
  return ShopFeeEntity(
    id: id,
    name: name,
    defaultAmount: defaultAmount,
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  Widget host(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              final cart = ref.watch(cartProvider);
              return FeeSection(cart: cart);
            },
          ),
        ),
      ),
    );
  }

  group('FeeSection — add flow', () {
    testWidgets('picking a fee with a default amount prefills an editable field',
        (tester) async {
      final container = ProviderContainer(overrides: [
        activeShopFeesProvider.overrideWith(
          (ref) => Stream.value([
            _shopFee(id: 'f1', name: 'Electric charge', defaultAmount: 50),
          ]),
        ),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(host(container));
      await tester.pump();

      // Section starts collapsed (no fee lines yet); expand it.
      await tester.tap(find.text('Shop Fees'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add fee line'));
      await tester.pumpAndSettle();

      // Picker lists the active catalog fee.
      expect(find.text('Electric charge'), findsOneWidget);
      await tester.tap(find.text('Electric charge'));
      await tester.pumpAndSettle();

      // Amount step prefills the default, editable.
      final amountField =
          tester.widget<TextFormField>(find.byKey(const Key('fee-amount-field')));
      expect(amountField.controller!.text, '50.00');

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.byType(FeeLineRow), findsOneWidget);
      expect(find.text('Electric charge'), findsOneWidget);
      expect(find.text('₱50.00'), findsOneWidget);
      expect(container.read(cartProvider).feeLines.single.amount, 50.0);
      expect(
          container.read(cartProvider).feeLines.single.name, 'Electric charge');
      expect(container.read(cartProvider).feeLines.single.id, isNotEmpty);
    });

    testWidgets('picking a fee with no default requires a manually entered amount',
        (tester) async {
      final container = ProviderContainer(overrides: [
        activeShopFeesProvider.overrideWith(
          (ref) => Stream.value([
            _shopFee(id: 'f2', name: 'Tire changer'),
          ]),
        ),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(host(container));
      await tester.pump();

      await tester.tap(find.text('Shop Fees'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add fee line'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tire changer'));
      await tester.pumpAndSettle();

      final amountField =
          tester.widget<TextFormField>(find.byKey(const Key('fee-amount-field')));
      expect(amountField.controller!.text, '');

      // Confirm with an empty amount is blocked.
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Amount must be greater than 0'), findsOneWidget);
      expect(container.read(cartProvider).feeLines, isEmpty);

      // Entering a valid amount confirms it.
      await tester.enterText(
          find.byKey(const Key('fee-amount-field')), '75');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(container.read(cartProvider).feeLines.single.amount, 75.0);
      expect(container.read(cartProvider).feeLines.single.name, 'Tire changer');
    });
  });

  testWidgets('remove clears the fee line from the cart', (tester) async {
    final container = ProviderContainer(overrides: [
      activeShopFeesProvider.overrideWith(
        (ref) => Stream.value(<ShopFeeEntity>[]),
      ),
    ]);
    addTearDown(container.dispose);
    container.read(cartProvider.notifier).addFeeLine(
          const FeeLineEntity(id: 'fl-1', name: 'Air', amount: 20),
        );

    await tester.pumpWidget(host(container));
    await tester.pump();
    // Non-empty fee lines auto-expand the section.
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FeeLineRow), findsOneWidget);
    await tester.tap(find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Remove fee line'));
    await tester.pumpAndSettle();

    expect(container.read(cartProvider).feeLines, isEmpty);
    expect(find.byType(FeeLineRow), findsNothing);
  });
}
