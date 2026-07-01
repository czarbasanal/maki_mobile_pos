import { describe, expect, it } from 'vitest';
import { priceChangeRowsInRange, type PriceChangeEntry } from './priceChangeReport';

const e = (
  productId: string,
  at: string,
  price: number,
  cost: number,
): PriceChangeEntry => ({
  id: `${productId}-${at}`,
  productId,
  price,
  cost,
  changedAt: new Date(at),
  changedBy: 'u1',
  reason: 'receiving',
  note: null,
});

describe('priceChangeRowsInRange', () => {
  it('groups by product, deltas vs prior, newest-first', () => {
    const rows = priceChangeRowsInRange([
      e('p1', '2026-06-10T09:00:00Z', 120, 70),
      e('p2', '2026-06-20T09:00:00Z', 250, 180),
      e('p1', '2026-06-01T09:00:00Z', 100, 60),
    ]);
    expect(rows.map((r) => r.entry.productId)).toEqual(['p2', 'p1', 'p1']);
    const p1Jun10 = rows[1];
    expect(p1Jun10.hasPrior).toBe(true);
    expect(p1Jun10.priceDelta).toBe(20);
    expect(rows[2].hasPrior).toBe(false); // oldest p1
  });

  it('empty -> empty', () => {
    expect(priceChangeRowsInRange([])).toEqual([]);
  });
});
