import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/product_search.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

ProductEntity _product({
  String name = 'BRAKE SHOE (YAMAHA)',
  String sku = '00070153',
  String? category = 'Brakes',
  List<String> barcodes = const ['4800888123457'],
}) =>
    ProductEntity(
      id: 'p1',
      sku: sku,
      name: name,
      costCode: 'NBF',
      cost: 100,
      price: 150,
      quantity: 5,
      reorderLevel: 1,
      unit: 'pcs',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      category: category,
      barcodes: barcodes,
    );

void main() {
  group('matchesProductQuery', () {
    test('matches substrings in name, sku, category, and barcodes', () {
      expect(matchesProductQuery(_product(), 'brake'), isTrue);
      expect(matchesProductQuery(_product(), '0007'), isTrue);
      expect(matchesProductQuery(_product(), 'brakes'), isTrue); // category
      expect(matchesProductQuery(_product(), '888123'), isTrue); // barcode infix
      expect(matchesProductQuery(_product(), 'clutch'), isFalse);
    });

    test('is word-order insensitive', () {
      expect(matchesProductQuery(_product(), 'shoe brake'), isTrue);
      expect(matchesProductQuery(_product(), 'yamaha shoe'), isTrue);
    });

    test('is whitespace insensitive', () {
      expect(matchesProductQuery(_product(), '  brake   shoe  '), isTrue);
      expect(matchesProductQuery(_product(), 'brake\tshoe'), isTrue);
    });

    test('tokens can straddle fields (sku + name)', () {
      expect(matchesProductQuery(_product(), '0007 brake'), isTrue);
    });

    test('matches a concatenated query against spaced words', () {
      expect(matchesProductQuery(_product(), 'brakeshoe'), isTrue);
    });

    test('every token must match (AND semantics)', () {
      expect(matchesProductQuery(_product(), 'brake clutch'), isFalse);
    });

    test('empty and blank queries match nothing', () {
      expect(matchesProductQuery(_product(), ''), isFalse);
      expect(matchesProductQuery(_product(), '   '), isFalse);
    });

    test('normalizes a typed dddd-dddd SKU back to the stored form', () {
      expect(matchesProductQuery(_product(), '0007-0153'), isTrue);
    });

    test('never matches across a field seam', () {
      // sku ends '…0153', barcode starts '4800…' — '1534' exists only at
      // the junction and must not match (a scan would add the WRONG part).
      expect(matchesProductQuery(_product(), '1534'), isFalse);
      expect(matchesProductQuery(_product(), '01534800'), isFalse);
    });

    test('still matches a genuinely dashed stored code by its raw form', () {
      expect(
        matchesProductQuery(
          _product(barcodes: const ['1234-5678']),
          '1234-5678',
        ),
        isTrue,
      );
    });

    test('tolerates a null category', () {
      expect(matchesProductQuery(_product(category: null), 'brake'), isTrue);
      expect(matchesProductQuery(_product(category: null), 'clutch'), isFalse);
    });
  });
}
