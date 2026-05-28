import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/payment_method.dart';

void main() {
  group('PaymentMethod salmon & mixed', () {
    test('salmon and mixed exist with correct values', () {
      expect(PaymentMethod.salmon.value, 'salmon');
      expect(PaymentMethod.salmon.displayName, 'Salmon');
      expect(PaymentMethod.mixed.value, 'mixed');
      expect(PaymentMethod.mixed.displayName, 'Mixed');
    });

    test('fromString resolves the new values', () {
      expect(PaymentMethod.fromString('salmon'), PaymentMethod.salmon);
      expect(PaymentMethod.fromString('mixed'), PaymentMethod.mixed);
    });

    test('new methods have no transaction fees', () {
      expect(PaymentMethod.salmon.hasFees, false);
      expect(PaymentMethod.mixed.hasFees, false);
    });
  });
}
