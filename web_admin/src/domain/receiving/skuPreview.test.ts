import { describe, expect, it } from 'vitest';
import { PENDING_SKU_LABEL, skuCellText } from './skuPreview';

describe('skuCellText', () => {
  it('shows no code for a row still awaiting allocation', () => {
    // The value carried on the row is only a floor for the registry scan.
    expect(skuCellText('00220001', true)).toBe(PENDING_SKU_LABEL);
  });

  it('never leaks the placeholder digits', () => {
    expect(skuCellText('00220001', true)).not.toMatch(/\d/);
  });

  it('two rows seeded with the same placeholder read identically as pending', () => {
    // This is the reported bug: three new products in one category all showed
    // the same code. They now all read as pending instead of as one SKU.
    expect(skuCellText('00220001', true)).toBe(skuCellText('00220001', true));
    expect(skuCellText('00220001', true)).toBe(PENDING_SKU_LABEL);
  });

  it('shows a typed SKU verbatim', () => {
    expect(skuCellText('MLK-A3B7', false)).toBe('MLK-A3B7');
    expect(skuCellText('00070153', false)).toBe('00070153');
  });
});
