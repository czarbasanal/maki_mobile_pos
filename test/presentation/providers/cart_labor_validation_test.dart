import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';

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
  late ProviderContainer container;
  late CartNotifier cart;

  setUp(() {
    container = ProviderContainer();
    cart = container.read(cartProvider.notifier);
  });

  tearDown(() => container.dispose());

  group('CartState labor validation', () {
    test('laborValid is true when there are no labor lines', () {
      cart.addProduct(_product());
      expect(container.read(cartProvider).laborValid, isTrue);
    });

    test('labor present but no mechanic -> invalid, blocks save and checkout',
        () {
      cart.addProduct(_product());
      cart.setAmountReceived(1000);
      cart.addLaborLine(description: 'Tune-up', fee: 450);

      final state = container.read(cartProvider);
      expect(state.laborValid, isFalse);
      expect(state.laborValidationError, isNotNull);
      expect(state.canSaveAsDraft, isFalse);
      expect(state.canCheckout, isFalse);
    });

    test('labor with mechanic and positive fee -> valid', () {
      cart.addProduct(_product());
      cart.setAmountReceived(1000);
      cart.addLaborLine(description: 'Tune-up', fee: 450);
      cart.setMechanic('m1', 'Juan');

      final state = container.read(cartProvider);
      expect(state.laborValid, isTrue);
      expect(state.canSaveAsDraft, isTrue);
      expect(state.canCheckout, isTrue);
    });

    test('a zero-fee labor line invalidates even with a mechanic', () {
      cart.addProduct(_product());
      cart.setMechanic('m1', 'Juan');
      cart.addLaborLine(description: 'Freebie', fee: 0);

      final state = container.read(cartProvider);
      expect(state.laborValid, isFalse);
      expect(state.canSaveAsDraft, isFalse);
    });
  });
}
