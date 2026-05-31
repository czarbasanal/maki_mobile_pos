import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/pos/checkout_screen.dart';

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
  testWidgets('checkout renders labor line, labor subtotal and mechanic',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cart = container.read(cartProvider.notifier);
    cart.addProduct(_product());
    cart.setPaymentMethod(PaymentMethod.cash);
    cart.setAmountReceived(1000);
    cart.addLaborLine(description: 'Engine tune-up', fee: 450);
    cart.setMechanic('m1', 'Juan Dela Cruz');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CheckoutScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // Labor line appears in the order list.
    expect(find.text('Engine tune-up'), findsOneWidget);
    // Labor subtotal row + mechanic line in the payment summary.
    expect(find.textContaining('Labor (1 service'), findsOneWidget);
    expect(find.textContaining('Mechanic: Juan Dela Cruz'), findsOneWidget);
    // Grand total is labor-inclusive: 100 + 450 = 550.
    expect(find.textContaining('₱550.00'), findsWidgets);
  });
}
