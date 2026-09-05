// Reason chips on the Price changes report are GROUPS, not the raw strings —
// prod carries 'receiving' (web) and 'Stock receiving' (mobile) for the same
// event, plus 'Price update' / 'Cost update' / 'Price + cost update' /
// 'Cost variation'. The chip counts and the KPI counts come from the same rows.
import { describe, expect, it } from 'vitest';
import type { PriceChangeRow } from './priceChangeReport';
import { priceChangeCounts, REASON_GROUPS, reasonGroup } from './priceChangeReason';

function row(o: { reason?: string | null; priceDelta?: number; hasPrior?: boolean; id?: string }): PriceChangeRow {
  return {
    entry: {
      id: o.id ?? 'e', productId: 'p', price: 100, cost: 50, changedAt: new Date(), changedBy: 'u',
      reason: o.reason === undefined ? 'Price update' : o.reason,
      optionId: null, optionLabel: null, optionPieces: null,
    },
    priceDelta: o.priceDelta ?? 0,
    costDelta: 0,
    hasPrior: o.hasPrior ?? true,
  };
}

describe('reasonGroup', () => {
  it('folds both receiving literals into Receiving (info)', () => {
    expect(reasonGroup('receiving')).toMatchObject({ key: 'receiving', label: 'Receiving', tone: 'info' });
    expect(reasonGroup('Stock receiving').key).toBe('receiving');
  });
  it('Initial price is neutral; Price update (and price+cost) take the accent; cost-only is neutral', () => {
    expect(reasonGroup('Initial price')).toMatchObject({ key: 'initial', label: 'Initial price', tone: 'neutral' });
    expect(reasonGroup('Price update')).toMatchObject({ key: 'price', label: 'Price update', tone: 'warning' });
    expect(reasonGroup('Price + cost update').key).toBe('price');
    expect(reasonGroup('Cost update')).toMatchObject({ key: 'cost', label: 'Cost update', tone: 'neutral' });
    expect(reasonGroup('Cost variation').key).toBe('cost');
  });
  it('the three selling-option reasons are one Options group', () => {
    for (const r of ['Option added', 'Option changed', 'Option removed']) {
      expect(reasonGroup(r)).toMatchObject({ key: 'options', label: 'Options', tone: 'neutral' });
    }
  });
  it('anything else (mobile promo set, null) is Other', () => {
    expect(reasonGroup('Promotion')).toMatchObject({ key: 'other', label: 'Other', tone: 'neutral' });
    expect(reasonGroup(null).key).toBe('other');
    expect(reasonGroup('').key).toBe('other');
  });
  it('REASON_GROUPS is the fixed chip order', () => {
    expect(REASON_GROUPS.map((g) => g.key)).toEqual(['receiving', 'initial', 'price', 'cost', 'options', 'other']);
  });
});

describe('priceChangeCounts', () => {
  const rows = [
    row({ id: '1', reason: 'receiving' }),
    row({ id: '2', reason: 'Stock receiving' }),
    row({ id: '3', reason: 'Initial price', hasPrior: false }),
    row({ id: '4', reason: 'Price update', priceDelta: 40 }),
    row({ id: '5', reason: 'Price update', priceDelta: -20 }),
    // a first-in-range entry with a positive delta but NO prior is not a rise
    row({ id: '6', reason: 'Promotion', priceDelta: 99, hasPrior: false }),
  ];
  it('counts logged, increases, cuts, new products and each group', () => {
    expect(priceChangeCounts(rows)).toEqual({
      logged: 6, increases: 1, cuts: 1, newProducts: 1,
      byGroup: { receiving: 2, initial: 1, price: 2, cost: 0, options: 0, other: 1 },
    });
  });
  it('is all zeros for an empty range', () => {
    expect(priceChangeCounts([])).toEqual({
      logged: 0, increases: 0, cuts: 0, newProducts: 0,
      byGroup: { receiving: 0, initial: 0, price: 0, cost: 0, options: 0, other: 0 },
    });
  });
});
