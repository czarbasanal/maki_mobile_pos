import { describe, expect, it } from 'vitest';
import { productDuplicateKey, productNameKey } from './nameKey';

// MIRRORED in test/core/utils/product_name_key_test.dart — the two
// implementations must agree token for token. Change one, change both.
const SHARED_VECTORS: [string, string][] = [
  ['BELT BANDO SKYDRIVE SPORT 115I', '115i bando belt skydrive sport'],
  ['CHAIN GLOBAL 428-120L', '428-120l chain global'],
  ['GLOBAL CHAIN 428-120L', '428-120l chain global'],
  ['TIRE TL MAXXIS MAV6 46P 90/90-14', '46p 90/90-14 mav6 maxxis tire tl'],
  ['  Yamalube   AT  Blue Core 10W-40  ', '10w-40 at blue core yamalube'],
];

describe('productNameKey', () => {
  it('agrees with the shared vector table', () => {
    for (const [input, expected] of SHARED_VECTORS) {
      expect(productNameKey(input)).toBe(expected);
    }
  });

  it('word order does not matter', () => {
    expect(productNameKey('CHAIN GLOBAL 428-120L')).toBe(
      productNameKey('GLOBAL CHAIN 428-120L'),
    );
  });

  it('keeps punctuation inside a token', () => {
    expect(productNameKey('TIRE 90/90-14')).toBe('90/90-14 tire');
    expect(productNameKey('TIRE 90/90-14')).not.toBe(productNameKey('TIRE 90/90-17'));
  });

  it('empty and whitespace-only names collapse to empty', () => {
    expect(productNameKey('')).toBe('');
    expect(productNameKey('   ')).toBe('');
  });
});

describe('productDuplicateKey', () => {
  it('includes the category', () => {
    expect(productDuplicateKey('BELT BANDO', 'CVT/TRANS')).toBe('bando belt|cvt/trans');
  });

  it('a null category is an empty segment, not the word null', () => {
    expect(productDuplicateKey('BELT BANDO', null)).toBe('bando belt|');
  });

  it('the same name in two categories does not collide', () => {
    expect(productDuplicateKey('GASKET', 'ENGINE')).not.toBe(
      productDuplicateKey('GASKET', 'BRAKES'),
    );
  });
});
