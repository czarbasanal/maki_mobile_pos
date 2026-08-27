import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/product_name_key.dart';

/// MIRRORED in web_admin/src/domain/products/nameKey.test.ts — the two
/// implementations must agree token for token. Change one, change both.
const sharedVectors = <List<String>>[
  ['BELT BANDO SKYDRIVE SPORT 115I', '115i bando belt skydrive sport'],
  ['CHAIN GLOBAL 428-120L', '428-120l chain global'],
  ['GLOBAL CHAIN 428-120L', '428-120l chain global'],
  ['TIRE TL MAXXIS MAV6 46P 90/90-14', '46p 90/90-14 mav6 maxxis tire tl'],
  ['  Yamalube   AT  Blue Core 10W-40  ', '10w-40 at blue core yamalube'],
];

void main() {
  group('productNameKey', () {
    test('agrees with the shared vector table', () {
      for (final v in sharedVectors) {
        expect(productNameKey(v[0]), v[1], reason: v[0]);
      }
    });

    test('word order does not matter', () {
      expect(
        productNameKey('CHAIN GLOBAL 428-120L'),
        productNameKey('GLOBAL CHAIN 428-120L'),
      );
    });

    test('keeps punctuation inside a token', () {
      // 90/90-14 is a tyre size — stripping the punctuation would merge
      // genuinely different sizes.
      expect(productNameKey('TIRE 90/90-14'), '90/90-14 tire');
      expect(productNameKey('TIRE 90/90-17'), '90/90-17 tire');
      expect(
        productNameKey('TIRE 90/90-14') == productNameKey('TIRE 90/90-17'),
        isFalse,
      );
    });

    test('empty and whitespace-only names collapse to empty', () {
      expect(productNameKey(''), '');
      expect(productNameKey('   '), '');
    });
  });

  group('productDuplicateKey', () {
    test('includes the category', () {
      expect(
        productDuplicateKey('BELT BANDO', 'CVT/TRANS'),
        'bando belt|cvt/trans',
      );
    });

    test('a null category is an empty segment, not the word null', () {
      expect(productDuplicateKey('BELT BANDO', null), 'bando belt|');
    });

    test('the same name in two categories does not collide', () {
      expect(
        productDuplicateKey('GASKET', 'ENGINE') ==
            productDuplicateKey('GASKET', 'BRAKES'),
        isFalse,
      );
    });
  });
}
