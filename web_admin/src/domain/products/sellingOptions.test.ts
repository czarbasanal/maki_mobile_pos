import { describe, expect, it } from 'vitest';
import type { SellingOption } from '../entities/SellingOption';
import { sellingOptionPricePerPiece } from '../entities/SellingOption';
import {
  parseSellingOptions,
  sellingOptionHistoryEvents,
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

describe('sellingOptionHistoryEvents', () => {
  const by3 = opt('o2', 'By 3', 3, 330);

  it('no change yields no events', () => {
    expect(sellingOptionHistoryEvents([by3], [by3], 60)).toEqual([]);
  });

  it('an added option logs Option added with its set cost', () => {
    const events = sellingOptionHistoryEvents([], [by3], 60);
    expect(events).toHaveLength(1);
    expect(events[0].reason).toBe('Option added');
    expect(events[0].price).toBe(330);
    expect(events[0].cost).toBe(180);
    expect(events[0].optionPieces).toBe(3);
  });

  it('a removed option logs Option removed with its last known price', () => {
    const events = sellingOptionHistoryEvents([by3], [], 60);
    expect(events[0].reason).toBe('Option removed');
    expect(events[0].price).toBe(330);
    expect(events[0].optionLabel).toBe('By 3');
  });

  it('a price-only change logs Price update', () => {
    const events = sellingOptionHistoryEvents([by3], [{ ...by3, price: 360 }], 60);
    expect(events[0].reason).toBe('Price update');
    expect(events[0].price).toBe(360);
  });

  it('a piece-count change logs Option changed', () => {
    const events = sellingOptionHistoryEvents([by3], [{ ...by3, pieces: 4, price: 440 }], 60);
    expect(events[0].reason).toBe('Option changed');
    expect(events[0].optionPieces).toBe(4);
    expect(events[0].cost).toBe(240);
  });

  it(
    'a piece-count change with the SAME price still logs Option changed ' +
      '(not Price update, not silence)',
    () => {
      const events = sellingOptionHistoryEvents([by3], [{ ...by3, pieces: 4 }], 60);
      expect(events[0].reason).toBe('Option changed');
      expect(events[0].price).toBe(330);
      expect(events[0].cost).toBe(240);
    },
  );

  it('a label-only rename logs nothing', () => {
    const events = sellingOptionHistoryEvents([by3], [{ ...by3, label: 'Half box' }], 60);
    expect(events).toEqual([]);
  });

  it('sub-centavo price drift logs nothing', () => {
    const events = sellingOptionHistoryEvents([by3], [{ ...by3, price: 330.005 }], 60);
    expect(events).toEqual([]);
  });

  it('handles several options changing at once', () => {
    const by6 = opt('o1', 'By 6', 6, 600);
    const events = sellingOptionHistoryEvents([by6, by3], [{ ...by6, price: 650 }], 60);
    expect(new Set(events.map((e) => e.reason))).toEqual(new Set(['Price update', 'Option removed']));
  });

  it(
    'a single call can produce every reason at once, and an unchanged ' +
      'option among the mix still produces nothing',
    () => {
      const a = opt('a', 'A', 2, 200); // unchanged
      const b = opt('b', 'B', 3, 300); // price-only change
      const c = opt('c', 'C', 4, 400); // pieces change (w/ price)
      const e = opt('e', 'E', 5, 500); // removed

      const events = sellingOptionHistoryEvents(
        [a, b, c, e],
        [a, { ...b, price: 330 }, { ...c, pieces: 6, price: 600 }, opt('d', 'D', 1, 100)],
        10,
      );

      const byOptionId = Object.fromEntries(events.map((ev) => [ev.optionId, ev.reason]));
      expect(byOptionId).toEqual({
        b: 'Price update',
        c: 'Option changed',
        d: 'Option added',
        e: 'Option removed',
      });
      // 'a' is absent entirely — no event for the unchanged option.
      expect(Object.prototype.hasOwnProperty.call(byOptionId, 'a')).toBe(false);

      const cEvent = events.find((ev) => ev.optionId === 'c')!;
      expect(cEvent.cost).toBe(60); // 6 pieces * 10 unit cost, not 10 itself.
    },
  );
});
