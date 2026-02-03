import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/extensions/extensions.dart';
import 'package:maki_mobile_pos/core/utils/utils.dart';

void main() {
  group('NumExtensions', () {
    test('toCurrency formats correctly', () {
      expect(1234.56.toCurrency(), '₱1,234.56');
      expect(1000.0.toCurrency(), '₱1,000.00');
    });

    test('applyPercentageDiscount calculates correctly', () {
      expect(100.0.applyPercentageDiscount(10), 90.0);
      expect(200.0.applyPercentageDiscount(25), 150.0);
    });
  });

  group('StringExtensions', () {
    test('isValidEmail validates correctly', () {
      expect('test@example.com'.isValidEmail, true);
      expect('invalid-email'.isValidEmail, false);
    });

    test('isValidPhilippineMobile validates correctly', () {
      expect('09171234567'.isValidPhilippineMobile, true);
      expect('+639171234567'.isValidPhilippineMobile, true);
      expect('1234567'.isValidPhilippineMobile, false);
    });

    test('toTitleCase converts correctly', () {
      expect('hello world'.toTitleCase(), 'Hello World');
    });
  });

  group('DateTimeExtensions', () {
    test('startOfDay returns midnight', () {
      final date = DateTime(2025, 1, 15, 14, 30, 45);
      expect(date.startOfDay, DateTime(2025, 1, 15, 0, 0, 0));
    });

    test('endOfDay returns end of day', () {
      final date = DateTime(2025, 1, 15, 14, 30, 45);
      final endOfDay = date.endOfDay;
      expect(endOfDay.hour, 23);
      expect(endOfDay.minute, 59);
      expect(endOfDay.second, 59);
    });
  });

  group('SkuGenerator', () {
    test('generate creates valid SKU', () {
      final sku = SkuGenerator.generate();
      expect(sku.startsWith('SKU-'), true);
      expect(SkuGenerator.isValidSku(sku), true);
    });

    test('generateVariation creates correct variation', () {
      expect(SkuGenerator.generateVariation('ABC123', 1), 'ABC123-1');
      expect(SkuGenerator.generateVariation('ABC123-1', 2), 'ABC123-2');
    });

    test('getNextVariationNumber returns correct number', () {
      final existing = ['ABC123', 'ABC123-1', 'ABC123-2'];
      expect(SkuGenerator.getNextVariationNumber('ABC123', existing), 3);
    });
  });

  group('Validators', () {
    test('required validates correctly', () {
      expect(Validators.required(null), isNotNull);
      expect(Validators.required(''), isNotNull);
      expect(Validators.required('value'), isNull);
    });

    test('price validates correctly', () {
      expect(Validators.price('100'), isNull);
      expect(Validators.price('-10'), isNotNull);
      expect(Validators.price('abc'), isNotNull);
    });

    test('discountPercentage validates correctly', () {
      expect(Validators.discountPercentage('10'), isNull);
      expect(Validators.discountPercentage('101'), isNotNull);
      expect(Validators.discountPercentage('-5'), isNotNull);
    });
  });
}
