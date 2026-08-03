import type { PriceHistoryEntry } from '../repositories/ProductRepository';

export interface PriceChangeEntry extends PriceHistoryEntry {
  id: string;
  productId: string;
}

export interface PriceChangeRow {
  entry: PriceChangeEntry;
  priceDelta: number;
  costDelta: number;
  hasPrior: boolean;
}

/** Groups by product AND selling option, computes deltas vs the prior in-range
 *  change per group (oldest-per-group has no prior), returns rows newest-first.
 *  A base per-piece price and an option's set price (e.g. a By-6 pack) are
 *  different series and must never be differenced against each other. */
export function priceChangeRowsInRange(entries: PriceChangeEntry[]): PriceChangeRow[] {
  const byProduct = new Map<string, PriceChangeEntry[]>();
  for (const e of entries) {
    // A base entry's optionId is null/undefined, so its key is stable and
    // distinct from any option's.
    const key = `${e.productId}::${e.optionId ?? ''}`;
    const list = byProduct.get(key) ?? [];
    list.push(e);
    byProduct.set(key, list);
  }

  const rows: PriceChangeRow[] = [];
  for (const group of byProduct.values()) {
    group.sort((a, b) => a.changedAt.getTime() - b.changedAt.getTime());
    let prior: PriceChangeEntry | null = null;
    for (const e of group) {
      rows.push({
        entry: e,
        priceDelta: prior ? e.price - prior.price : 0,
        costDelta: prior ? e.cost - prior.cost : 0,
        hasPrior: prior !== null,
      });
      prior = e;
    }
  }
  rows.sort((a, b) => b.entry.changedAt.getTime() - a.entry.changedAt.getTime());
  return rows;
}
