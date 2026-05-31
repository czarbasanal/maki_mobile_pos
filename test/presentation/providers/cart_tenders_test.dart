import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';

ProductEntity _product(double price) => ProductEntity(
      id: 'p1', sku: 'SKU1', name: 'Item', costCode: '', cost: 0,
      price: price, quantity: 100, reorderLevel: 0, unit: 'pcs',
      isActive: true, createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late CartNotifier cart;
  setUp(() {
    cart = CartNotifier();
    cart.addProduct(_product(1000)); // grandTotal = 1000
  });

  test('single cash: tenders = {cash: grandTotal}, change from amount', () {
    cart.setPaymentMethod(PaymentMethod.cash);
    cart.setAmountReceived(1200);
    expect(cart.state.tenders, {PaymentMethod.cash: 1000});
    expect(cart.state.change, 200);
    expect(cart.state.isPaymentValid, true);
  });

  test('single gcash: exact tender, no change, valid', () {
    cart.setPaymentMethod(PaymentMethod.gcash);
    expect(cart.state.tenders, {PaymentMethod.gcash: 1000});
    expect(cart.state.change, 0);
    expect(cart.state.isPaymentValid, true);
  });

  test('mixed: cash remainder + digital; valid only when 0<digital<total', () {
    cart.setPaymentMethod(PaymentMethod.mixed);
    cart.setSecondaryMethod(PaymentMethod.gcash);
    cart.setSplitAmount(700);
    expect(cart.state.tenders,
        {PaymentMethod.cash: 300, PaymentMethod.gcash: 700});
    expect(cart.state.isPaymentValid, true);

    cart.setSplitAmount(1000); // not a split
    expect(cart.state.isPaymentValid, false);
    cart.setSplitAmount(0);
    expect(cart.state.isPaymentValid, false);
  });

  test('salmon: downpayment + salmon balance; only DP collected', () {
    cart.setPaymentMethod(PaymentMethod.salmon);
    cart.setSecondaryMethod(PaymentMethod.cash); // DP method
    cart.setSplitAmount(400); // downpayment
    expect(cart.state.tenders,
        {PaymentMethod.cash: 400, PaymentMethod.salmon: 600});
    expect(cart.state.isPaymentValid, true);
    expect(cart.state.change, 0);
    expect(cart.state.collectedToday, 400);

    cart.setSplitAmount(1000); // no balance -> invalid as salmon
    expect(cart.state.isPaymentValid, false);
  });

  test('labor raises grandTotal so cash tender + change track the total', () {
    cart.addLaborLine(description: 'Tune-up', fee: 500); // grandTotal -> 1500
    cart.setPaymentMethod(PaymentMethod.cash);
    cart.setAmountReceived(2000);

    expect(cart.state.grandTotal, 1500);
    expect(cart.state.tenders, {PaymentMethod.cash: 1500});
    expect(cart.state.change, 500);
    expect(cart.state.isPaymentValid, true);
  });

  test('mixed split is taken over the labor-inclusive grandTotal', () {
    cart.addLaborLine(description: 'Labor', fee: 500); // grandTotal -> 1500
    cart.setPaymentMethod(PaymentMethod.mixed);
    cart.setSecondaryMethod(PaymentMethod.gcash);
    cart.setSplitAmount(600);

    expect(cart.state.tenders,
        {PaymentMethod.cash: 900, PaymentMethod.gcash: 600});
    expect(cart.state.isPaymentValid, true);
  });
}
