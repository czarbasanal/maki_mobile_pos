import { describe, expect, it } from 'vitest';
import {
  PriceMetric,
  buildPriceHistoryRows,
  sparklineSeries,
  derivePriceHistorySource,
  sparklinePath,
  splitPriceHistorySeries,
} from './priceHistory';
import type { PriceHistoryEntry } from '../repositories/ProductRepository';

// Note: these fixtures don't set `note` — the helper tests never read
// `entry.note` (the receiving/RCV case is tested via raw string args below), so
// the fixtures stay valid even before Task 2 adds the optional `note` field.
function e(
  id: string,
  price: number,
  cost: number,
  reason: string | null,
): PriceHistoryEntry & { id: string } {
  return { id, price, cost, changedAt: new Date(2026, 0, 1), changedBy: 'u1', reason };
}

// Fixture for splitPriceHistorySeries — TS PriceHistoryEntry has no `id` field
// (unlike the Dart PriceHistoryEntry, which requires one).
function opt(
  day: number,
  price: number,
  optionId?: string,
  optionLabel?: string,
  optionPieces?: number,
): PriceHistoryEntry {
  return {
    price,
    cost: 60,
    changedAt: new Date(2026, 6, day),
    changedBy: 'u1',
    reason: 'Price update',
    optionId: optionId ?? null,
    optionLabel: optionLabel ?? null,
    optionPieces: optionPieces ?? null,
  };
}

// newest-first, like listPriceHistory returns
const entries: PriceHistoryEntry[] = [
  e('e3', 120, 70, 'Price update'),
  e('e2', 110, 70, 'Stock receiving'),
  e('e1', 110, 60, 'Initial price'),
];

describe('buildPriceHistoryRows', () => {
  it('all metric keeps every entry with deltas vs the older entry', () => {
    const rows = buildPriceHistoryRows(entries, PriceMetric.all);
    expect(rows.length).toBe(3);
    expect(rows[0].priceDelta).toBeCloseTo(10);
    expect(rows[0].costDelta).toBeCloseTo(0);
    expect(rows[0].hasPrior).toBe(true);
    expect(rows[2].hasPrior).toBe(false);
    expect(rows[2].priceDelta).toBe(0);
  });

  it('price filter keeps origin + entries where price moved', () => {
    const rows = buildPriceHistoryRows(entries, PriceMetric.price);
    expect(rows.map((r) => (r.entry as unknown as { id: string }).id)).toEqual(['e3', 'e1']);
  });

  it('cost filter keeps origin + entries where cost moved', () => {
    const rows = buildPriceHistoryRows(entries, PriceMetric.cost);
    expect(rows.map((r) => (r.entry as unknown as { id: string }).id)).toEqual(['e2', 'e1']);
  });

  it('empty input yields no rows', () => {
    expect(buildPriceHistoryRows([], PriceMetric.all)).toEqual([]);
  });
});

describe('sparklineSeries', () => {
  it('returns price values oldest-first', () => {
    expect(sparklineSeries(entries, false)).toEqual([110, 110, 120]);
  });
  it('returns cost values oldest-first', () => {
    expect(sparklineSeries(entries, true)).toEqual([60, 70, 70]);
  });
});

describe('derivePriceHistorySource', () => {
  it('maps known reasons', () => {
    expect(derivePriceHistorySource('Initial price', null)).toBe('Created');
    expect(derivePriceHistorySource('Price update', null)).toBe('Manual edit');
    expect(derivePriceHistorySource('Cost update', null)).toBe('Manual edit');
    expect(derivePriceHistorySource('Price + cost update', null)).toBe('Manual edit');
  });
  it('receiving appends the RCV id from note when present', () => {
    expect(derivePriceHistorySource('Stock receiving', 'RCV-20260201-003')).toBe(
      'Receiving (RCV-20260201-003)',
    );
    expect(derivePriceHistorySource('Stock receiving', null)).toBe('Receiving');
  });
  it('null/empty reason -> Edit; unknown shown as-is', () => {
    expect(derivePriceHistorySource(null, null)).toBe('Edit');
    expect(derivePriceHistorySource('', null)).toBe('Edit');
    expect(derivePriceHistorySource('Promotion', null)).toBe('Promotion');
  });
  it('labels the new reasons on the Source column', () => {
    expect(derivePriceHistorySource('Option added', null)).toBe('Option added');
    expect(derivePriceHistorySource('Option removed', null)).toBe('Option removed');
    expect(derivePriceHistorySource('Option changed', null)).toBe('Option changed');
  });
});

describe('splitPriceHistorySeries', () => {
  it('entries with no option fields form a single base series', () => {
    const series = splitPriceHistorySeries([opt(2, 130), opt(1, 120)]);
    expect(series).toHaveLength(1);
    expect(series[0].optionId).toBeNull();
    expect(series[0].label).toBe('Base price');
    expect(series[0].entries).toHaveLength(2);
  });

  it('separates base and option entries', () => {
    const series = splitPriceHistorySeries([
      opt(3, 360, 'o2', 'By 3', 3),
      opt(2, 130),
      opt(1, 330, 'o2', 'By 3', 3),
    ]);
    expect(series.map((s) => s.label)).toEqual(['Base price', 'By 3']);
    expect(series[0].entries).toHaveLength(1);
    expect(series[1].entries).toHaveLength(2);
  });

  it('keeps each series newest-first', () => {
    const series = splitPriceHistorySeries([
      opt(3, 360, 'o2', 'By 3', 3),
      opt(1, 330, 'o2', 'By 3', 3),
    ]);
    expect(series[0].entries[0].price).toBe(360);
  });

  it('omits the base series when there are no base entries', () => {
    const series = splitPriceHistorySeries([opt(1, 330, 'o2', 'By 3', 3)]);
    expect(series.map((s) => s.label)).toEqual(['By 3']);
  });

  it('deltas computed per series never mix base and option prices', () => {
    const series = splitPriceHistorySeries([
      opt(3, 360, 'o2', 'By 3', 3),
      opt(2, 130),
      opt(1, 330, 'o2', 'By 3', 3),
    ]);
    const optionRows = buildPriceHistoryRows(series[1].entries, PriceMetric.price);
    expect(optionRows[0].priceDelta).toBe(30);
  });

  it('several options each get their own series, in first-seen order', () => {
    const series = splitPriceHistorySeries([
      opt(2, 600, 'o1', 'By 6', 6),
      opt(1, 330, 'o2', 'By 3', 3),
    ]);
    expect(series.map((s) => s.label)).toEqual(['By 6', 'By 3']);
  });
});

describe('sparklinePath', () => {
  it('returns empty for fewer than 2 points', () => {
    expect(sparklinePath([5], 100, 40)).toBe('');
    expect(sparklinePath([], 100, 40)).toBe('');
  });
  it('maps min to the bottom and max to the top', () => {
    expect(sparklinePath([10, 20], 100, 40)).toBe('M0.00,40.00 L100.00,0.00');
  });
  it('centres a flat series', () => {
    expect(sparklinePath([5, 5], 100, 40)).toBe('M0.00,20.00 L100.00,20.00');
  });
});
