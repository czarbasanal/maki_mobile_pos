import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';

void main() {
  group('toCurrencyCompact', () {
    test('drops decimals when whole, groups thousands', () {
      expect(1250.toCurrencyCompact(), '₱1,250');
      expect(180.0.toCurrencyCompact(), '₱180');
    });
    test('keeps 2 decimals when fractional', () {
      expect(180.5.toCurrencyCompact(), '₱180.50');
    });
  });

  test('toCurrency groups thousands with 2 decimals', () {
    expect(1250.0.toCurrency(), '₱1,250.00');
  });
}
