import { describe, expect, it } from 'vitest';
import { nextVariationNumber, removeVariationSuffix, variationSku } from './variations';

describe('removeVariationSuffix', () => {
  it('strips a numeric -N suffix only', () => {
    expect(removeVariationSuffix('ABC123-2')).toBe('ABC123');
    expect(removeVariationSuffix('rs8-001')).toBe('rs8'); // numeric suffix stripped
    expect(removeVariationSuffix('ABC123')).toBe('ABC123');
  });
});

describe('variationSku', () => {
  it('appends -N verbatim', () => {
    expect(variationSku('ABC123', 1)).toBe('ABC123-1');
    expect(variationSku('rs8-001', 2)).toBe('rs8-001-2');
  });
});

describe('nextVariationNumber', () => {
  it('returns 1 when no variations exist', () => {
    expect(nextVariationNumber('ABC123', ['ABC123', 'XYZ'])).toBe(1);
  });

  it('returns max+1 over existing -N variations', () => {
    expect(nextVariationNumber('ABC123', ['ABC123', 'ABC123-1', 'ABC123-2'])).toBe(3);
  });

  it('ignores non-numeric suffixes', () => {
    expect(nextVariationNumber('ABC123', ['ABC123-blue', 'ABC123-1'])).toBe(2);
  });
});
