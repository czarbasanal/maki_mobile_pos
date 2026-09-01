import { describe, expect, it } from 'vitest';
import { cartFeesTotal, cartGrandTotal, cartHasBillableContent, cartLineId, lowStockLines, stockShortfalls } from './cart';
import { DiscountType } from '@/domain/enums/DiscountType';
import type { Product } from '@/domain/entities';
import type { CartLine } from './cart';

const line = (over: Partial<CartLine> = {}): CartLine => ({
  id: 'p1', productId: 'p1', sku: 'A', name: 'A',
  unitPrice: 100, unitCost: 60, quantity: 1, discountValue: 0, unit: 'pcs',
  optionId: null, optionLabel: null, optionPieces: null, optionPrice: null,
  ...over,
});

describe('cartGrandTotal', () => {
  it('sums net of per-line amount discounts (no labor)', () => {
    expect(
      cartGrandTotal(
        [line({ quantity: 2 }), line({ productId: 'p2', discountValue: 20 })],
        [],
        DiscountType.amount,
      ),
    ).toBe(200 + 80);
  });
  it('applies percentage discounts (no labor)', () => {
    expect(cartGrandTotal([line({ discountValue: 10 })], [], DiscountType.percentage)).toBe(90);
  });
  it('adds described labor on top of parts', () => {
    expect(
      cartGrandTotal(
        [line({ quantity: 2 })],
        [
          { id: 'l1', description: 'Tune-up', fee: 300 },
          { id: 'l2', description: '   ', fee: 999 }, // blank desc → excluded
        ],
        DiscountType.amount,
      ),
    ).toBe(200 + 300);
  });
  it('adds carried shop fees on top of parts + labor (money-correctness carry from a resumed job order)', () => {
    expect(
      cartGrandTotal(
        [line({ quantity: 2 })],
        [{ id: 'l1', description: 'Tune-up', fee: 300 }],
        DiscountType.amount,
        [{ id: 'f1', name: 'Convenience fee', amount: 50, description: null }],
      ),
    ).toBe(200 + 300 + 50);
  });
  it('defaults to no fees when feeLines is omitted (a plain non-JO cart)', () => {
    expect(cartGrandTotal([line()], [], DiscountType.amount)).toBe(100);
  });
});

describe('cartFeesTotal', () => {
  it('sums fee line amounts', () => {
    expect(
      cartFeesTotal([
        { id: 'f1', name: 'Convenience fee', amount: 50, description: null },
        { id: 'f2', name: 'Disposal fee', amount: 25, description: null },
      ]),
    ).toBe(75);
  });
  it('returns 0 for an empty list', () => {
    expect(cartFeesTotal([])).toBe(0);
  });
});

describe('lowStockLines', () => {
  it('flags lines whose qty exceeds on-hand', () => {
    const products = [{ id: 'p1', quantity: 1 }, { id: 'p2', quantity: 5 }] as Product[];
    const flagged = lowStockLines([line({ quantity: 3 }), line({ productId: 'p2', quantity: 2 })], products);
    expect([...flagged]).toEqual(['p1']);
  });

  // Two option lines of the same product draw on the same on-hand pieces, so
  // stock must be checked against their SUMMED quantity, not each line alone.
  // Neither line here exceeds 8 individually (6 and 3) — only the sum (9) does.
  it('sums quantity across option lines of the same product', () => {
    const lines = [
      line({ id: 'p1::o1', productId: 'p1', quantity: 6 }),
      line({ id: 'p1::o2', productId: 'p1', quantity: 3 }),
    ];
    const products = [{ id: 'p1', quantity: 8 }] as Product[];
    expect(lowStockLines(lines, products)).toEqual(new Set(['p1']));
  });

  it('does not flag when the summed quantity fits', () => {
    const lines = [
      line({ id: 'p1::o1', productId: 'p1', quantity: 6 }),
      line({ id: 'p1::o2', productId: 'p1', quantity: 3 }),
    ];
    const products = [{ id: 'p1', quantity: 9 }] as Product[];
    expect(lowStockLines(lines, products)).toEqual(new Set());
  });
});

describe('cartLineId', () => {
  it('is the product id when there is no option', () => {
    expect(cartLineId('p1', null)).toBe('p1');
  });

  it('combines product and option ids when there is one', () => {
    expect(cartLineId('p1', 'o2')).toBe('p1::o2');
  });
});

describe('cartHasBillableContent (labor/fee-only sales allowed)', () => {
  it('false for a fully empty cart', () => {
    expect(cartHasBillableContent([], [], [])).toBe(false);
  });
  it('true with only a described labor line', () => {
    expect(
      cartHasBillableContent([], [{ id: 'l', description: 'Change oil', fee: 150 }], []),
    ).toBe(true);
  });
  it('false when the only labor line is undescribed', () => {
    expect(cartHasBillableContent([], [{ id: 'l', description: ' ', fee: 150 }], [])).toBe(false);
  });
  it('true with only a carried shop fee', () => {
    expect(cartHasBillableContent([], [], [{ id: 'f', name: 'Disposal', amount: 50, description: null }])).toBe(true);
  });
});

describe('stockShortfalls (completion warnings)', () => {
  const p = (id: string, name: string, quantity: number): Product =>
    ({ id, name, quantity, isActive: true }) as Product;
  const line = (productId: string, quantity: number): CartLine =>
    ({ id: productId, productId, name: 'x', quantity }) as CartLine;

  it('reports products whose total cart quantity exceeds on-hand', () => {
    const out = stockShortfalls(
      [line('a', 6), { ...line('a', 3), id: 'a::opt' }, line('b', 1)],
      [p('a', 'A', 5), p('b', 'B', 10)],
    );
    expect(out).toEqual([{ productId: 'a', name: 'x', requested: 9, onHand: 5 }]);
  });

  it('empty when everything is covered', () => {
    expect(stockShortfalls([line('b', 1)], [p('b', 'B', 10)])).toEqual([]);
  });
});
