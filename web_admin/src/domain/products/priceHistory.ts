// Port of lib/core/utils/price_history_view.dart. Pure, framework-free, so it
// is unit-tested in node env. Uses RELATIVE imports (vitest doesn't resolve @/).
import type { PriceHistoryEntry } from '../repositories/ProductRepository';

export const PriceMetric = { all: 'all', price: 'price', cost: 'cost' } as const;
export type PriceMetric = (typeof PriceMetric)[keyof typeof PriceMetric];

export interface PriceHistoryRow {
  entry: PriceHistoryEntry;
  priceDelta: number;
  costDelta: number;
  hasPrior: boolean;
}

// One centavo. Matches the ▲/▼ display threshold in PriceHistoryView's `Delta`,
// so a kept row always shows its arrow.
const EPS = 0.01;

/**
 * Builds display rows from `entriesNewestFirst` (as `listPriceHistory` returns),
 * filtered to `metric`. Deltas are computed against the chronologically previous
 * (older = next-in-list) entry. The oldest entry has no prior, so its deltas are
 * 0 and it is always kept (origin of every series). For price/cost, an entry is
 * kept when it has no prior OR that metric moved by more than EPS.
 */
export function buildPriceHistoryRows(
  entriesNewestFirst: PriceHistoryEntry[],
  metric: PriceMetric,
): PriceHistoryRow[] {
  const rows: PriceHistoryRow[] = [];
  for (let i = 0; i < entriesNewestFirst.length; i += 1) {
    const entry = entriesNewestFirst[i];
    const prior = i + 1 < entriesNewestFirst.length ? entriesNewestFirst[i + 1] : null;
    const hasPrior = prior !== null;
    const priceDelta = hasPrior ? entry.price - prior.price : 0;
    const costDelta = hasPrior ? entry.cost - prior.cost : 0;

    let keep: boolean;
    if (metric === PriceMetric.price) keep = !hasPrior || Math.abs(priceDelta) > EPS;
    else if (metric === PriceMetric.cost) keep = !hasPrior || Math.abs(costDelta) > EPS;
    else keep = true;

    if (keep) rows.push({ entry, priceDelta, costDelta, hasPrior });
  }
  return rows;
}

/** Metric values in chronological order (oldest -> newest) for the sparkline. */
export function sparklineSeries(entriesNewestFirst: PriceHistoryEntry[], forCost: boolean): number[] {
  return entriesNewestFirst.map((entry) => (forCost ? entry.cost : entry.price)).reverse();
}

/** Maps a price-history reason (+ optional note) to a "Source" column label. */
export function derivePriceHistorySource(
  reason: string | null | undefined,
  note: string | null | undefined,
): string {
  switch (reason) {
    case 'Initial price':
      return 'Created';
    case 'Price update':
    case 'Cost update':
    case 'Price + cost update':
      return 'Manual edit';
    case 'Stock receiving': {
      const rcv = note ? /RCV-\d{8}-\d+/.exec(note)?.[0] ?? null : null;
      return rcv ? `Receiving (${rcv})` : 'Receiving';
    }
    case null:
    case undefined:
    case '':
      return 'Edit';
    default:
      return reason;
  }
}

/**
 * SVG path `d` for a sparkline. `values` are chronological; auto-scaled so the
 * min sits at the bottom and the max at the top. A flat series renders a
 * centred line. Returns '' for fewer than 2 points (caller hides the chart).
 */
export function sparklinePath(values: number[], width: number, height: number): string {
  if (values.length < 2) return '';
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = max - min;
  const stepX = width / (values.length - 1);
  return values
    .map((v, i) => {
      const x = i * stepX;
      const y = span === 0 ? height / 2 : height - ((v - min) / span) * height;
      return `${i === 0 ? 'M' : 'L'}${x.toFixed(2)},${y.toFixed(2)}`;
    })
    .join(' ');
}
