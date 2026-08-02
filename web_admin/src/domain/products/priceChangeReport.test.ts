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

function opt(
  id: string,
  price: number,
  day: number,
  option?: { id: string; label: string; pieces: number },
): PriceChangeEntry {
  return {
    id,
    productId: 'p1',
    price,
    cost: 60,
    changedAt: new Date(`2026-07-0${day}T00:00:00Z`),
    changedBy: 'u1',
    reason: 'Price update',
    optionId: option?.id ?? null,
    optionLabel: option?.label ?? null,
    optionPieces: option?.pieces ?? null,
  };
}

const by3 = { id: 'o2', label: 'By 3', pieces: 3 };
const by6 = { id: 'o1', label: 'By 6', pieces: 6 };

describe('priceChangeRowsInRange with selling options', () => {
  it('computes an option delta against the same option only, not a base '
    + 'entry that sits between them chronologically', () => {
    const rows = priceChangeRowsInRange([
      opt('e1', 330, 1, by3),
      opt('e2', 130, 2),
      opt('e3', 360, 3, by3),
    ]);
    const optionRow = rows.find((r) => r.entry.id === 'e3');
    // Wrong (flat-grouped by product only) would compute 360 - 130 = 230.
    expect(optionRow?.priceDelta).toBe(30);
    expect(optionRow?.hasPrior).toBe(true);
  });

  it('never subtracts an option price from a base price', () => {
    const rows = priceChangeRowsInRange([
      opt('e1', 120, 1),
      opt('e2', 330, 2, by3),
    ]);
    const optionRow = rows.find((r) => r.entry.id === 'e2');
    // Wrong (flat-grouped) would compute 330 - 120 = 210.
    expect(optionRow?.priceDelta).toBe(0);
    expect(optionRow?.hasPrior).toBe(false);
  });

  it('computes a base delta ignoring option entries in between', () => {
    const rows = priceChangeRowsInRange([
      opt('e1', 120, 1),
      opt('e2', 330, 2, by3),
      opt('e3', 130, 3),
    ]);
    // Wrong (flat-grouped, prior = e2) would compute 130 - 330 = -200.
    expect(rows.find((r) => r.entry.id === 'e3')?.priceDelta).toBe(10);
  });

  it('keeps two options of one product in separate groups', () => {
    const rows = priceChangeRowsInRange([
      opt('e1', 600, 1, by6),
      opt('e2', 330, 2, by3),
      opt('e3', 650, 3, by6),
    ]);
    // Wrong (all three in one group sorted by date) would compute
    // 650 - 330 = 320 for e3, and would give e2 a false prior instead of
    // being the lone by3 entry.
    expect(rows.find((r) => r.entry.id === 'e3')?.priceDelta).toBe(50);
    expect(rows.find((r) => r.entry.id === 'e2')?.hasPrior).toBe(false);
  });

  it('is unchanged for a product with no options', () => {
    const rows = priceChangeRowsInRange([opt('e1', 120, 1), opt('e2', 130, 2)]);
    expect(rows.map((r) => r.entry.id)).toEqual(['e2', 'e1']);
    expect(rows[0].priceDelta).toBe(10);
  });

  it('still returns rows newest-first across groups', () => {
    const rows = priceChangeRowsInRange([
      opt('e1', 120, 1),
      opt('e3', 360, 3, by3),
      opt('e2', 330, 2, by3),
    ]);
    expect(rows.map((r) => r.entry.id)).toEqual(['e3', 'e2', 'e1']);
  });
});

// Same fixture as test/core/utils/price_change_report_test.dart's
// "parity fixture (matches web priceChangeReport.test.ts)" — this is the
// side-by-side parity demonstration for Task 19a, not just an assertion that
// the two happen to agree. Keep the numbers identical on both sides.
describe('parity fixture (matches Dart price_change_report_test.dart)', () => {
  it('base and two options of one product, interleaved input order', () => {
    const p1 = (
      id: string,
      price: number,
      cost: number,
      day: number,
      option?: { id: string; label: string; pieces: number },
    ): PriceChangeEntry => ({
      id,
      productId: 'p1',
      price,
      cost,
      changedAt: new Date(`2026-07-0${day}T00:00:00Z`),
      changedBy: 'u1',
      reason: 'Price update',
      optionId: option?.id ?? null,
      optionLabel: option?.label ?? null,
      optionPieces: option?.pieces ?? null,
    });

    const rows = priceChangeRowsInRange([
      p1('e1', 100, 60, 1), // base
      p1('e2', 300, 150, 2, by3),
      p1('e3', 140, 65, 3), // base
      p1('e4', 345, 160, 4, by3),
      p1('e5', 600, 300, 5, by6),
    ]);

    expect(rows.map((r) => r.entry.id)).toEqual(['e5', 'e4', 'e3', 'e2', 'e1']);

    const byId = new Map(rows.map((r) => [r.entry.id, r]));
    expect(byId.get('e5')?.priceDelta).toBe(0);
    expect(byId.get('e5')?.hasPrior).toBe(false);
    expect(byId.get('e4')?.priceDelta).toBe(45); // 345 - 300, by3 series only
    expect(byId.get('e4')?.hasPrior).toBe(true);
    expect(byId.get('e4')?.costDelta).toBe(10); // 160 - 150
    expect(byId.get('e3')?.priceDelta).toBe(40); // 140 - 100, base series only
    expect(byId.get('e3')?.hasPrior).toBe(true);
    expect(byId.get('e3')?.costDelta).toBe(5); // 65 - 60
    expect(byId.get('e2')?.priceDelta).toBe(0);
    expect(byId.get('e2')?.hasPrior).toBe(false);
    expect(byId.get('e1')?.priceDelta).toBe(0);
    expect(byId.get('e1')?.hasPrior).toBe(false);
  });
});
