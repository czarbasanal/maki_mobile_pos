import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';

void main() {
  late ProviderContainer container;
  late CartNotifier cartNotifier;

  setUp(() {
    container = ProviderContainer();
    cartNotifier = container.read(cartProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  ProductEntity createTestProduct({
    String id = 'prod-1',
    String sku = 'SKU-001',
    String name = 'Test Product',
    double price = 100.0,
    double cost = 60.0,
  }) {
    return ProductEntity(
      id: id,
      sku: sku,
      name: name,
      costCode: 'NBF',
      cost: cost,
      price: price,
      quantity: 100,
      reorderLevel: 10,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  group('CartNotifier', () {
    test('initial state should be empty', () {
      final state = container.read(cartProvider);

      expect(state.isEmpty, true);
      expect(state.items, isEmpty);
      expect(state.grandTotal, 0);
    });

    test('addProduct should add new item', () {
      final product = createTestProduct();

      cartNotifier.addProduct(product);

      final state = container.read(cartProvider);
      expect(state.items.length, 1);
      expect(state.items.first.productId, 'prod-1');
      expect(state.items.first.quantity, 1);
    });

    test('addProduct should increase quantity for existing product', () {
      final product = createTestProduct();

      cartNotifier.addProduct(product);
      cartNotifier.addProduct(product, quantity: 2);

      final state = container.read(cartProvider);
      expect(state.items.length, 1);
      expect(state.items.first.quantity, 3);
    });

    test('updateItemQuantity should update quantity', () {
      final product = createTestProduct();
      cartNotifier.addProduct(product);
      final itemId = container.read(cartProvider).items.first.id;

      cartNotifier.updateItemQuantity(itemId, 5);

      final state = container.read(cartProvider);
      expect(state.items.first.quantity, 5);
    });

    test('updateItemQuantity to 0 should remove item', () {
      final product = createTestProduct();
      cartNotifier.addProduct(product);
      final itemId = container.read(cartProvider).items.first.id;

      cartNotifier.updateItemQuantity(itemId, 0);

      final state = container.read(cartProvider);
      expect(state.isEmpty, true);
    });

    test('removeItem should remove item', () {
      final product = createTestProduct();
      cartNotifier.addProduct(product);
      final itemId = container.read(cartProvider).items.first.id;

      cartNotifier.removeItem(itemId);

      final state = container.read(cartProvider);
      expect(state.isEmpty, true);
    });

    test('subtotal should calculate correctly', () {
      cartNotifier.addProduct(createTestProduct(price: 100), quantity: 2);
      cartNotifier.addProduct(
        createTestProduct(id: 'prod-2', sku: 'SKU-002', price: 50),
        quantity: 3,
      );

      final state = container.read(cartProvider);
      // 100*2 + 50*3 = 350
      expect(state.subtotal, 350);
    });

    test('setDiscountType should reset item discounts', () {
      final product = createTestProduct();
      cartNotifier.addProduct(product);
      final itemId = container.read(cartProvider).items.first.id;

      // Apply discount
      cartNotifier.applyItemDiscount(itemId, 10);
      expect(container.read(cartProvider).items.first.discountValue, 10);

      // Change discount type
      cartNotifier.setDiscountType(DiscountType.percentage);

      final state = container.read(cartProvider);
      expect(state.discountType, DiscountType.percentage);
      expect(state.items.first.discountValue, 0); // Reset
    });

    test('applyItemDiscount with amount type', () {
      final product = createTestProduct(price: 100);
      cartNotifier.addProduct(product, quantity: 2);
      final itemId = container.read(cartProvider).items.first.id;

      cartNotifier.applyItemDiscount(itemId, 20);

      final state = container.read(cartProvider);
      expect(state.items.first.discountValue, 20);
      expect(state.totalDiscount, 20);
      expect(state.grandTotal, 180); // 200 - 20
    });

    test('applyItemDiscount with percentage type', () {
      final product = createTestProduct(price: 100);
      cartNotifier.addProduct(product, quantity: 2);
      final itemId = container.read(cartProvider).items.first.id;

      cartNotifier.setDiscountType(DiscountType.percentage);
      cartNotifier.applyItemDiscount(itemId, 10); // 10%

      final state = container.read(cartProvider);
      expect(state.items.first.discountValue, 10);
      expect(state.totalDiscount, 20); // 200 * 10% = 20
      expect(state.grandTotal, 180);
    });

    test('setAmountReceived and change calculation', () {
      final product = createTestProduct(price: 100);
      cartNotifier.addProduct(product);

      cartNotifier.setAmountReceived(150);

      final state = container.read(cartProvider);
      expect(state.amountReceived, 150);
      expect(state.change, 50);
      expect(state.isPaymentSufficient, true);
    });

    test('canCheckout should be true when conditions are met', () {
      final product = createTestProduct(price: 100);
      cartNotifier.addProduct(product);
      cartNotifier.setAmountReceived(100);

      final state = container.read(cartProvider);
      expect(state.canCheckout, true);
    });

    test('canCheckout should be false when cart is empty', () {
      cartNotifier.setAmountReceived(100);

      final state = container.read(cartProvider);
      expect(state.canCheckout, false);
    });

    test('canCheckout should be false when payment insufficient', () {
      final product = createTestProduct(price: 100);
      cartNotifier.addProduct(product);
      cartNotifier.setAmountReceived(50);

      final state = container.read(cartProvider);
      expect(state.canCheckout, false);
    });

    test('loadFromDraft should load draft state', () {
      final draft = DraftEntity(
        id: 'draft-1',
        name: 'Test Draft',
        items: const [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Test Product',
            unitPrice: 100,
            unitCost: 60,
            quantity: 2,
            discountValue: 10,
          ),
        ],
        discountType: DiscountType.amount,
        createdBy: 'user-1',
        createdByName: 'John',
        createdAt: DateTime.now(),
        notes: 'Draft notes',
      );

      cartNotifier.loadFromDraft(draft);

      final state = container.read(cartProvider);
      expect(state.items.length, 1);
      expect(state.sourceDraftId, 'draft-1');
      expect(state.notes, 'Draft notes');
      expect(state.isFromDraft, true);
    });

    test('reset should clear all state', () {
      final product = createTestProduct();
      cartNotifier.addProduct(product);
      cartNotifier.setAmountReceived(100);
      cartNotifier.setNotes('Test notes');

      cartNotifier.reset();

      final state = container.read(cartProvider);
      expect(state.isEmpty, true);
      expect(state.amountReceived, 0);
      expect(state.notes, isNull);
    });

    test('toSale should create valid SaleEntity', () {
      final product = createTestProduct(price: 100);
      cartNotifier.addProduct(product, quantity: 2);
      cartNotifier.setAmountReceived(200);
      cartNotifier.setNotes('Test sale');

      final sale = cartNotifier.toSale(
        saleNumber: 'SALE-001',
        cashierId: 'cashier-1',
        cashierName: 'John Doe',
      );

      expect(sale.saleNumber, 'SALE-001');
      expect(sale.items.length, 1);
      expect(sale.grandTotal, 200);
      expect(sale.changeGiven, 0);
      expect(sale.notes, 'Test sale');
    });

    test('toDraft should create valid DraftEntity', () {
      final product = createTestProduct();
      cartNotifier.addProduct(product);
      cartNotifier.setNotes('Test draft');

      final draft = cartNotifier.toDraft(
        name: 'My Draft',
        createdBy: 'user-1',
        createdByName: 'John Doe',
      );

      expect(draft.name, 'My Draft');
      expect(draft.items.length, 1);
      expect(draft.notes, 'Test draft');
    });
  });

  group('Derived Providers', () {
    test('isCartEmptyProvider should reflect cart state', () {
      expect(container.read(isCartEmptyProvider), true);

      cartNotifier.addProduct(createTestProduct());

      expect(container.read(isCartEmptyProvider), false);
    });

    test('cartItemCountProvider should reflect item count', () {
      expect(container.read(cartItemCountProvider), 0);

      cartNotifier.addProduct(createTestProduct(), quantity: 3);

      expect(container.read(cartItemCountProvider), 3);
    });

    test('cartGrandTotalProvider should reflect grand total', () {
      expect(container.read(cartGrandTotalProvider), 0);

      cartNotifier.addProduct(createTestProduct(price: 100), quantity: 2);

      expect(container.read(cartGrandTotalProvider), 200);
    });
  });
}
