import { describe, expect, it } from 'vitest';
import { cartFeesTotal, cartGrandTotal, lowStockLines } from './cart';
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
        [{ id: 'f1', name: 'Convenience fee', amount: 50 }],
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
        { id: 'f1', name: 'Convenience fee', amount: 50 },
        { id: 'f2', name: 'Disposal fee', amount: 25 },
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
});
