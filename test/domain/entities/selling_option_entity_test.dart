// test/domain/entities/selling_option_entity_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('SellingOptionEntity', () {
    test('pricePerPiece divides the set price by the piece count', () {
      const option =
          SellingOptionEntity(id: 'a', label: 'By 3', pieces: 3, price: 330);
      expect(option.pricePerPiece, 110);
    });

    test('pricePerPiece keeps full precision for a non-terminating divide', () {
      const option =
          SellingOptionEntity(id: 'a', label: 'By 3', pieces: 3, price: 100);
      expect(option.pricePerPiece * 3, closeTo(100, 0.0001));
    });

    test('is value-equal on the same fields', () {
      const a = SellingOptionEntity(id: 'a', label: 'By 6', pieces: 6, price: 600);
      const b = SellingOptionEntity(id: 'a', label: 'By 6', pieces: 6, price: 600);
      expect(a, b);
    });

    test('copyWith replaces only the named field', () {
      const a = SellingOptionEntity(id: 'a', label: 'By 6', pieces: 6, price: 600);
      expect(a.copyWith(price: 650).price, 650);
      expect(a.copyWith(price: 650).label, 'By 6');
    });
  });
}
