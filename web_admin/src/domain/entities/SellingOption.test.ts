import { describe, expect, it } from 'vitest';
import { sellingOptionRateSuffix } from './SellingOption';

describe('sellingOptionRateSuffix', () => {
  // "pcs" is the only plural default in the product data — every other unit
  // (box, set, pack, ...) already reads fine as typed, so only this one gets
  // special-cased down to its singular "pc".
  it('special-cases "pcs" to "pc"', () => {
    expect(sellingOptionRateSuffix('pcs')).toBe('pc');
  });

  it('returns any other unit unchanged', () => {
    expect(sellingOptionRateSuffix('box')).toBe('box');
    expect(sellingOptionRateSuffix('set')).toBe('set');
    expect(sellingOptionRateSuffix('pack')).toBe('pack');
  });
});
