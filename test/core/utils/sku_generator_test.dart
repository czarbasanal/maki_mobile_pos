import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/sku_generator.dart';

void main() {
  group('generate', () {
    test('produces SKU-<8 unambiguous alnum>', () {
      for (var i = 0; i < 50; i++) {
        final sku = SkuGenerator.generate();
        expect(sku, matches(RegExp(r'^SKU-[A-Z0-9]{8}$')));
        // No ambiguous characters (0/O, 1/I/L) in the random part.
        expect(sku.substring(4), isNot(matches(RegExp(r'[01OIL]'))));
        expect(SkuGenerator.isValidSku(sku), isTrue);
      }
    });

    test('generateWithPrefix uses the given prefix', () {
      expect(SkuGenerator.generateWithPrefix('PROD'),
          matches(RegExp(r'^PROD-[A-Z0-9]{8}$')));
    });
  });

  group('generateForName', () {
    test('slugifies, keeps first letter, drops later vowels, truncates to 10',
        () {
      expect(SkuGenerator.generateForName('Milk Chocolate 500g Box'),
          matches(RegExp(r'^MLKCHCLT50-[A-Z0-9]{6}$')));
      expect(SkuGenerator.generateForName('Beverages'),
          matches(RegExp(r'^BVRGS-[A-Z0-9]{6}$')));
    });

    test('keeps a leading vowel so short names stay recognisable', () {
      expect(SkuGenerator.generateForName('Ice'),
          matches(RegExp(r'^IC-[A-Z0-9]{6}$')));
    });

    test('falls back to generate() when the slug is empty', () {
      expect(SkuGenerator.generateForName(null),
          matches(RegExp(r'^SKU-[A-Z0-9]{8}$')));
      expect(SkuGenerator.generateForName('!!! ###'),
          matches(RegExp(r'^SKU-[A-Z0-9]{8}$')));
    });
  });

  group('slug / normalize keys (must match the backfill scripts)', () {
    test('slugifyForSku uppercases and strips non-alphanumerics', () {
      expect(SkuGenerator.slugifyForSku('a b-c.1'), 'ABC1');
    });

    test('normalizeSku trims and uppercases', () {
      expect(SkuGenerator.normalizeSku('  abc-1 '), 'ABC-1');
    });

    test('normalizeBarcode trims only (case-sensitive)', () {
      expect(SkuGenerator.normalizeBarcode('  Ab12 '), 'Ab12');
    });
  });

  group('isClaimableBarcode', () {
    test('accepts a normal code, rejects empty / dot / slash / reserved', () {
      expect(SkuGenerator.isClaimableBarcode('4800123456789'), isTrue);
      expect(SkuGenerator.isClaimableBarcode(''), isFalse);
      expect(SkuGenerator.isClaimableBarcode('.'), isFalse);
      expect(SkuGenerator.isClaimableBarcode('..'), isFalse);
      expect(SkuGenerator.isClaimableBarcode('a/b'), isFalse);
      expect(SkuGenerator.isClaimableBarcode('__x__'), isFalse);
      expect(SkuGenerator.isClaimableBarcode('x' * 1501), isFalse);
    });
  });

  group('variations', () {
    test('generateVariation appends the number verbatim', () {
      expect(SkuGenerator.generateVariation('ABC123', 1), 'ABC123-1');
      expect(SkuGenerator.generateVariation('rs8-001', 2), 'rs8-001-2');
    });

    test('getNextVariationNumber returns 1 when only the base exists', () {
      expect(SkuGenerator.getNextVariationNumber('ABC123', ['ABC123']), 1);
    });

    test('getNextVariationNumber returns max+1 across existing variations', () {
      expect(
        SkuGenerator.getNextVariationNumber(
            'ABC123', ['ABC123', 'ABC123-1', 'ABC123-2']),
        3,
      );
    });

    test('getNextVariationNumber skips gaps (max+1, not first-free)', () {
      expect(
        SkuGenerator.getNextVariationNumber('ABC123', ['ABC123-2']),
        3,
      );
    });

    test('isVariationOf', () {
      expect(SkuGenerator.isVariationOf('ABC123-2', 'ABC123'), isTrue);
      expect(SkuGenerator.isVariationOf('ABC123', 'ABC123'), isFalse);
      expect(SkuGenerator.isVariationOf('XYZ789', 'ABC123'), isFalse);
    });

    test('getVariationNumber', () {
      expect(SkuGenerator.getVariationNumber('ABC123-2'), 2);
      expect(SkuGenerator.getVariationNumber('ABC123'), isNull);
    });

    test('getBaseSku / removeVariationSuffix strip only a numeric tail', () {
      expect(SkuGenerator.getBaseSku('ABC123-2'), 'ABC123');
      expect(SkuGenerator.getBaseSku('ABC123'), 'ABC123');
      // Non-numeric tail is preserved.
      expect(SkuGenerator.removeVariationSuffix('ABC-XL'), 'ABC-XL');
      // KNOWN QUIRK: a numeric tail in a user SKU is read as a variation.
      expect(SkuGenerator.removeVariationSuffix('rs8-001'), 'rs8');
    });
  });

  group('isValidSku', () {
    test('accepts alphanumerics + hyphen up to 50 chars', () {
      expect(SkuGenerator.isValidSku('ABC-123'), isTrue);
      expect(SkuGenerator.isValidSku('a' * 50), isTrue);
    });

    test('rejects empty, too long, spaces, and other symbols', () {
      expect(SkuGenerator.isValidSku(''), isFalse);
      expect(SkuGenerator.isValidSku('a' * 51), isFalse);
      expect(SkuGenerator.isValidSku('ABC 123'), isFalse);
      expect(SkuGenerator.isValidSku('ABC_123'), isFalse);
    });
  });

  group('Code128 auto-SKU format', () {
    test('composeAutoSku pads category code to 4 digits then appends sequence',
        () {
      expect(SkuGenerator.composeAutoSku('0007', 153), '00070153');
      expect(SkuGenerator.composeAutoSku('0001', 1), '00010001');
      expect(SkuGenerator.composeAutoSku('1234', 9999), '12349999');
    });

    test('composeAutoSku asserts code is exactly 4 digits', () {
      expect(
        () => SkuGenerator.composeAutoSku('007', 1),
        throwsAssertionError,
      );
      expect(
        () => SkuGenerator.composeAutoSku('00070', 1),
        throwsAssertionError,
      );
      expect(
        () => SkuGenerator.composeAutoSku('ABCD', 1),
        throwsAssertionError,
      );
    });

    test('composeAutoSku asserts sequence is 1..9999', () {
      expect(
        () => SkuGenerator.composeAutoSku('0007', 0),
        throwsAssertionError,
      );
      expect(
        () => SkuGenerator.composeAutoSku('0007', 10000),
        throwsAssertionError,
      );
    });

    test('matchesAutoPattern checks 8 digits and starts with code', () {
      expect(SkuGenerator.matchesAutoPattern('00070153', '0007'), isTrue);
      expect(SkuGenerator.matchesAutoPattern('00010001', '0001'), isTrue);
    });

    test('matchesAutoPattern rejects wrong length', () {
      expect(SkuGenerator.matchesAutoPattern('0007015', '0007'), isFalse);
      expect(SkuGenerator.matchesAutoPattern('000701530', '0007'), isFalse);
    });

    test('matchesAutoPattern rejects wrong prefix', () {
      expect(SkuGenerator.matchesAutoPattern('00080153', '0007'), isFalse);
    });

    test('matchesAutoPattern rejects non-numeric', () {
      expect(SkuGenerator.matchesAutoPattern('0007ABCD', '0007'), isFalse);
      expect(SkuGenerator.matchesAutoPattern('MLK-A3B7', '0007'), isFalse);
    });

    test('matchesAutoPattern validates categoryCode is exactly 4 digits', () {
      expect(SkuGenerator.matchesAutoPattern('00070153', ''), isFalse);
      expect(SkuGenerator.matchesAutoPattern('00070153', '007'), isFalse);
      expect(SkuGenerator.matchesAutoPattern('00070153', '00071'), isFalse);
      expect(SkuGenerator.matchesAutoPattern('00070153', 'ABCD'), isFalse);
    });

    test('displaySku passthrough for non-8-digit', () {
      expect(SkuGenerator.displaySku('00070153-1'), '00070153-1');
    });

    test('sequenceOf extracts last 4 digits as int', () {
      expect(SkuGenerator.sequenceOf('00070153'), 153);
      expect(SkuGenerator.sequenceOf('00010001'), 1);
      expect(SkuGenerator.sequenceOf('12349999'), 9999);
    });

    test('displaySku formats 8-digit numeric as 0007-0153', () {
      expect(SkuGenerator.displaySku('00070153'), '0007-0153');
      expect(SkuGenerator.displaySku('00010001'), '0001-0001');
      expect(SkuGenerator.displaySku('12349999'), '1234-9999');
    });

    test('displaySku leaves non-8-digit or non-numeric unchanged', () {
      expect(SkuGenerator.displaySku('MLK-A3B7'), 'MLK-A3B7');
      expect(SkuGenerator.displaySku('0007015'), '0007015');
      expect(SkuGenerator.displaySku('000701530'), '000701530');
      expect(SkuGenerator.displaySku('SKU-ABCD1234'), 'SKU-ABCD1234');
    });
  });
}
