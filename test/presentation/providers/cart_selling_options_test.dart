import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';

ProductEntity product() => ProductEntity(
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

void main() {
  const by6 = SellingOptionEntity(id: 'o1', label: 'By 6', pieces: 6, price: 600);
  const by3 = SellingOptionEntity(id: 'o2', label: 'By 3', pieces: 3, price: 330);

  late ProviderContainer container;
  CartNotifier notifier() => container.read(cartProvider.notifier);
  CartState state() => container.read(cartProvider);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  group('cart with selling options', () {
    test('the same option twice merges into one line of six pieces', () {
      notifier().addProductOption(product(), by3);
      notifier().addProductOption(product(), by3);
      expect(state().items, hasLength(1));
      expect(state().items.first.quantity, 6);
      expect(state().items.first.optionSets, 2);
    });

    test('two different options of one product stay separate lines', () {
      notifier().addProductOption(product(), by6);
      notifier().addProductOption(product(), by3);
      expect(state().items, hasLength(2));
      expect(state().items.map((i) => i.optionLabel), ['By 6', 'By 3']);
    });

    test('an option line and a plain line stay separate', () {
      notifier().addProduct(product());
      notifier().addProductOption(product(), by3);
      expect(state().items, hasLength(2));
    });

    test('plain lines still merge on product as before', () {
      notifier().addProduct(product());
      notifier().addProduct(product());
      expect(state().items, hasLength(1));
      expect(state().items.first.quantity, 2);
    });

    test('increment steps by the option piece count', () {
      notifier().addProductOption(product(), by3);
      notifier().incrementItemQuantity(state().items.first.id);
      expect(state().items.first.quantity, 6);
    });

    test('decrement steps down by the option piece count', () {
      notifier().addProductOption(product(), by3, sets: 2);
      notifier().decrementItemQuantity(state().items.first.id);
      expect(state().items.first.quantity, 3);
    });

    test('decrementing the last set removes the line', () {
      notifier().addProductOption(product(), by3);
      notifier().decrementItemQuantity(state().items.first.id);
      expect(state().items, isEmpty);
    });

    test('plain lines still step by one', () {
      notifier().addProduct(product());
      notifier().incrementItemQuantity(state().items.first.id);
      expect(state().items.first.quantity, 2);
    });
  });
}
