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

/** Groups by product, computes deltas vs the prior in-range change per product
 *  (oldest-per-product has no prior), returns rows newest-first. */
export function priceChangeRowsInRange(entries: PriceChangeEntry[]): PriceChangeRow[] {
  const byProduct = new Map<string, PriceChangeEntry[]>();
  for (const e of entries) {
    const list = byProduct.get(e.productId) ?? [];
    list.push(e);
    byProduct.set(e.productId, list);
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
