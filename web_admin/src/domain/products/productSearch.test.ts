import { describe, expect, it } from 'vitest';
import { matchesProductQuery } from './productSearch';

const p = (over: Partial<Parameters<typeof matchesProductQuery>[0]> = {}) => ({
  name: 'BRAKE SHOE (YAMAHA)',
  sku: '00070153',
  category: 'Brakes',
  barcodes: ['4800888123457'],
  ...over,
});

describe('matchesProductQuery', () => {
  it('matches plain substrings in name, sku, category, and barcodes', () => {
    expect(matchesProductQuery(p(), 'brake')).toBe(true);
    expect(matchesProductQuery(p(), '0007')).toBe(true);
    expect(matchesProductQuery(p(), 'brakes')).toBe(true); // category
    expect(matchesProductQuery(p(), '888123')).toBe(true); // barcode infix
    expect(matchesProductQuery(p(), 'clutch')).toBe(false);
  });

  it('is word-order insensitive', () => {
    expect(matchesProductQuery(p(), 'shoe brake')).toBe(true);
    expect(matchesProductQuery(p(), 'yamaha shoe')).toBe(true);
  });

  it('is whitespace insensitive', () => {
    expect(matchesProductQuery(p(), '  brake   shoe  ')).toBe(true);
    expect(matchesProductQuery(p(), 'brake\tshoe')).toBe(true);
  });

  it('tokens can straddle fields (sku + name)', () => {
    expect(matchesProductQuery(p(), '0007 brake')).toBe(true);
  });

  it('matches a concatenated query against spaced words', () => {
    expect(matchesProductQuery(p(), 'brakeshoe')).toBe(true);
  });

  it('every token must match (AND semantics)', () => {
    expect(matchesProductQuery(p(), 'brake clutch')).toBe(false);
  });

  it('empty and blank queries match nothing', () => {
    expect(matchesProductQuery(p(), '')).toBe(false);
    expect(matchesProductQuery(p(), '   ')).toBe(false);
  });

  it('never matches across a field seam', () => {
    // sku ends '…0153', barcode starts '4800…' — '1534' exists only at the
    // junction and must not match (a wedge scan would add the WRONG part).
    expect(matchesProductQuery(p(), '1534')).toBe(false);
    expect(matchesProductQuery(p(), '01534800')).toBe(false);
  });

  it('folds a dashed dddd-dddd token to the stored SKU form', () => {
    expect(matchesProductQuery(p(), '0007-0153')).toBe(true);
  });

  it('still matches a genuinely dashed stored code by its raw form', () => {
    expect(matchesProductQuery(p({ barcodes: ['1234-5678'] }), '1234-5678')).toBe(true);
  });

  it('tolerates a null category', () => {
    expect(matchesProductQuery(p({ category: null }), 'brake')).toBe(true);
    // 'brakes' still matches via the concatenation fallback ("brakeshoe…") —
    // assert with a token that exists nowhere in any field.
    expect(matchesProductQuery(p({ category: null }), 'clutch')).toBe(false);
  });
});
