import { describe, expect, it } from 'vitest';
import { stockTotals } from './stockTotals';

describe('stockTotals', () => {
  it('returns zeros for an empty list', () => {
    expect(stockTotals([])).toEqual({ cost: 0, retail: 0, profit: 0 });
  });

  it('sums cost*qty and price*qty and derives profit', () => {
    const totals = stockTotals([
      { cost: 100, price: 250, quantity: 2 },
      { cost: 50, price: 80, quantity: 10 },
    ]);
    expect(totals).toEqual({ cost: 700, retail: 1300, profit: 600 });
  });

  it('counts zero-quantity items as zero contribution', () => {
    expect(stockTotals([{ cost: 999, price: 1999, quantity: 0 }])).toEqual({
      cost: 0,
      retail: 0,
      profit: 0,
    });
  });
});
