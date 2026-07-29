import { describe, expect, it } from 'vitest';
import type { SellingOption } from '../entities/SellingOption';
import { sellingOptionPricePerPiece } from '../entities/SellingOption';
import {
  parseSellingOptions,
  serializeSellingOptions,
  validateSellingOptions,
} from './sellingOptions';

const opt = (id: string, label: string, pieces: number, price: number): SellingOption => ({
  id,
  label,
  pieces,
  price,
});

describe('sellingOptionPricePerPiece', () => {
  it('divides the set price by the piece count', () => {
    expect(sellingOptionPricePerPiece(opt('a', 'By 3', 3, 330))).toBe(110);
  });

  it('keeps full precision for a non-terminating divide', () => {
    expect(sellingOptionPricePerPiece(opt('a', 'By 3', 3, 100)) * 3).toBeCloseTo(100, 4);
  });

  it('returns 0 rather than Infinity when pieces is 0', () => {
    expect(sellingOptionPricePerPiece(opt('a', 'By 3', 0, 100))).toBe(0);
  });
});

describe('validateSellingOptions', () => {
  it('accepts an empty list', () => {
    expect(validateSellingOptions([])).toBeNull();
  });

  it('accepts a well-formed list', () => {
    expect(validateSellingOptions([opt('a', 'By 6', 6, 600), opt('b', 'By 3', 3, 330)])).toBeNull();
  });

  it('rejects a blank label', () => {
    expect(validateSellingOptions([opt('a', '   ', 6, 600)])).not.toBeNull();
  });

  it('rejects a label over 24 characters', () => {
    expect(validateSellingOptions([opt('a', 'x'.repeat(25), 6, 600)])).not.toBeNull();
  });

  it('rejects duplicate labels case-insensitively', () => {
    expect(
      validateSellingOptions([opt('a', 'By 6', 6, 600), opt('b', 'by 6', 3, 330)]),
    ).not.toBeNull();
  });

  it('rejects pieces below 1', () => {
    expect(validateSellingOptions([opt('a', 'By 6', 0, 600)])).not.toBeNull();
  });

  it('rejects a price of zero or less', () => {
    expect(validateSellingOptions([opt('a', 'By 6', 6, 0)])).not.toBeNull();
  });

  it('rejects more than 10 options', () => {
    const many = Array.from({ length: 11 }, (_, i) => opt(`${i}`, `By ${i}`, i + 1, 100));
    expect(validateSellingOptions(many)).not.toBeNull();
  });

  it('accepts exactly 10 options', () => {
    const ten = Array.from({ length: 10 }, (_, i) => opt(`${i}`, `By ${i}`, i + 1, 100));
    expect(validateSellingOptions(ten)).toBeNull();
  });
});

describe('parseSellingOptions', () => {
  it('returns empty for undefined', () => {
    expect(parseSellingOptions(undefined)).toEqual([]);
  });

  it('returns empty for a non-array', () => {
    expect(parseSellingOptions('nope')).toEqual([]);
  });

  it('skips entries missing an id or label', () => {
    expect(
      parseSellingOptions([
        { id: '', label: 'By 6', pieces: 6, price: 600 },
        { id: 'b', label: '', pieces: 3, price: 330 },
        { id: 'c', label: 'By 3', pieces: 3, price: 330 },
      ]),
    ).toEqual([opt('c', 'By 3', 3, 330)]);
  });

  it('round-trips through serializeSellingOptions', () => {
    const options = [opt('a', 'By 6', 6, 600), opt('b', 'By 3', 3, 330)];
    expect(parseSellingOptions(serializeSellingOptions(options))).toEqual(options);
  });

  describe('type tolerance for pieces and price', () => {
    it('falls back to pieces: 1 for string pieces', () => {
      const parsed = parseSellingOptions([{ id: 'a', label: 'By 6', pieces: 'abc', price: 600 }]);
      expect(parsed).toEqual([opt('a', 'By 6', 1, 600)]);
    });

    it('falls back to pieces: 1 for boolean pieces', () => {
      const parsed = parseSellingOptions([{ id: 'a', label: 'By 6', pieces: false, price: 600 }]);
      expect(parsed).toEqual([opt('a', 'By 6', 1, 600)]);
    });

    it('truncates fractional pieces (6.7 → 6)', () => {
      const parsed = parseSellingOptions([{ id: 'a', label: 'By 6', pieces: 6.7, price: 600 }]);
      expect(parsed).toEqual([opt('a', 'By 6', 6, 600)]);
    });

    it('falls back to price: 0 for string price', () => {
      const parsed = parseSellingOptions([{ id: 'a', label: 'By 6', pieces: 6, price: 'abc' }]);
      expect(parsed).toEqual([opt('a', 'By 6', 6, 0)]);
    });

    it('falls back to price: 0 for boolean price', () => {
      const parsed = parseSellingOptions([{ id: 'a', label: 'By 6', pieces: 6, price: true }]);
      expect(parsed).toEqual([opt('a', 'By 6', 6, 0)]);
    });

    it('falls back to pieces: 1 for array pieces', () => {
      const parsed = parseSellingOptions([{ id: 'a', label: 'By 6', pieces: [], price: 600 }]);
      expect(parsed).toEqual([opt('a', 'By 6', 1, 600)]);
    });

    it('falls back to pieces: 1 for object pieces', () => {
      const parsed = parseSellingOptions([{ id: 'a', label: 'By 6', pieces: {}, price: 600 }]);
      expect(parsed).toEqual([opt('a', 'By 6', 1, 600)]);
    });

    it('falls back to price: 0 for array price', () => {
      const parsed = parseSellingOptions([{ id: 'a', label: 'By 6', pieces: 6, price: [] }]);
      expect(parsed).toEqual([opt('a', 'By 6', 6, 0)]);
    });

    it('falls back to price: 0 for object price', () => {
      const parsed = parseSellingOptions([{ id: 'a', label: 'By 6', pieces: 6, price: {} }]);
      expect(parsed).toEqual([opt('a', 'By 6', 6, 0)]);
    });
  });
});
