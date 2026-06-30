import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';

/// Regression for the "Confirm Payment disabled for non-cash tenders" bug.
/// Reproduces the checkout flow as the UI drives it: pick a method, then enter
/// the relevant amount — WITHOUT manually re-tapping the secondary-method
/// segment (which the UI shows pre-selected).
void main() {
  late ProviderContainer container;
  late CartNotifier cart;

  setUp(() {
    container = ProviderContainer();
    cart = container.read(cartProvider.notifier);
    cart.addProduct(ProductEntity(
      id: 'p1',
      sku: 'S1',
      name: 'Item',
      costCode: 'NBF',
      cost: 60,
      price: 100,
      quantity: 100,
      reorderLevel: 10,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    ));
  });

  tearDown(() => container.dispose());

  bool canCheckout() => container.read(cartProvider).canCheckout;

  test('cash with exact tender can check out', () {
    cart.setPaymentMethod(PaymentMethod.cash);
    cart.setAmountReceived(100);
    expect(canCheckout(), isTrue);
  });

  test('gcash can check out (collected in full)', () {
    cart.setPaymentMethod(PaymentMethod.gcash);
    expect(canCheckout(), isTrue);
  });

  test('maya can check out (collected in full)', () {
    cart.setPaymentMethod(PaymentMethod.maya);
    expect(canCheckout(), isTrue);
  });

  test('mixed: entering the digital split is enough (UI shows GCash preselected)',
      () {
    cart.setPaymentMethod(PaymentMethod.mixed);
    // User types the digital portion but never taps the GCash segment, since
    // the UI already shows it selected.
    cart.setSplitAmount(40);
    expect(canCheckout(), isTrue);
  });

  test('salmon: entering the downpayment is enough (UI shows Cash preselected)',
      () {
    cart.setPaymentMethod(PaymentMethod.salmon);
    cart.setSplitAmount(40);
    expect(canCheckout(), isTrue);
  });
}
