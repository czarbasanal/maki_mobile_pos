import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/pos/checkout_screen.dart';

// Found beyond the task brief's named render sites: the pre-payment order
// review is the same "cart tile" surface as CartItemTile, just read-only.
// Reuses the exact CartNotifier.addProductOption seam already exercised by
// test/presentation/providers/cart_selling_options_test.dart, so no picker
// UI is needed to get an option line into the cart.

ProductEntity _product() => ProductEntity(
      id: 'p1',
      sku: 'ABC-1',
      name: 'Pulley Ball',
      costCode: 'NBF',
      cost: 60,
      price: 120,
      quantity: 12,
      reorderLevel: 3,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 7, 29),
    );

const _by3 = SellingOptionEntity(id: 'o2', label: 'By 3', pieces: 3, price: 330);

Future<void> _pump(WidgetTester tester, void Function(CartNotifier) seed) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final container = ProviderContainer();
  addTearDown(container.dispose);
  final cart = container.read(cartProvider.notifier);
  seed(cart);
  cart.setPaymentMethod(PaymentMethod.cash);
  cart.setAmountReceived(1000);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CheckoutScreen()),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('shows the option label beside the name for a single set',
      (tester) async {
    await _pump(tester, (cart) => cart.addProductOption(_product(), _by3));
    expect(find.textContaining('By 3'), findsWidgets);
    expect(find.textContaining('× 2'), findsNothing);
  });

  testWidgets('shows the set count and total pieces for more than one set',
      (tester) async {
    await _pump(tester, (cart) {
      cart.addProductOption(_product(), _by3);
      cart.addProductOption(_product(), _by3);
    });
    expect(find.textContaining('By 3 × 2'), findsOneWidget);
    expect(find.textContaining('6 pcs'), findsOneWidget);
  });

  testWidgets('a plain line renders unchanged', (tester) async {
    await _pump(tester, (cart) => cart.addProduct(_product()));
    expect(find.textContaining('By'), findsNothing);
  });
}
