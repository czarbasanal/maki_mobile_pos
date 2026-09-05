// Reason GROUPS for the Price changes report (reports guide §1): the chips,
// the Reason column tag and the KPI counts all read from these, so the
// web's 'receiving' and mobile's 'Stock receiving' are one chip.
import type { PriceChangeRow } from './priceChangeReport';

/** Badge tones the chips use — a subset of the ui Badge's Tone, kept here so the domain stays UI-free. */
export type ReasonTone = 'info' | 'neutral' | 'warning';

export type ReasonGroupKey = 'receiving' | 'initial' | 'price' | 'cost' | 'options' | 'other';

export interface ReasonGroup {
  key: ReasonGroupKey;
  label: string;
  tone: ReasonTone;
}

/** Fixed chip order. */
export const REASON_GROUPS: readonly ReasonGroup[] = [
  { key: 'receiving', label: 'Receiving', tone: 'info' },
  { key: 'initial', label: 'Initial price', tone: 'neutral' },
  { key: 'price', label: 'Price update', tone: 'warning' },
  { key: 'cost', label: 'Cost update', tone: 'neutral' },
  { key: 'options', label: 'Options', tone: 'neutral' },
  { key: 'other', label: 'Other', tone: 'neutral' },
];

const byKey = Object.fromEntries(REASON_GROUPS.map((g) => [g.key, g])) as Record<ReasonGroupKey, ReasonGroup>;

export function reasonGroup(reason: string | null | undefined): ReasonGroup {
  switch (reason) {
    case 'receiving':
    case 'Stock receiving':
      return byKey.receiving;
    case 'Initial price':
      return byKey.initial;
    case 'Price update':
    case 'Price + cost update':
      return byKey.price;
    case 'Cost update':
    case 'Cost variation':
      return byKey.cost;
    // Selling-option events (sellingOptions.ts / selling_options.dart).
    case 'Option added':
    case 'Option changed':
    case 'Option removed':
      return byKey.options;
    default:
      return byKey.other;
  }
}

export interface PriceChangeCounts {
  logged: number;
  /** Rows whose price rose vs the prior in-range change (a first entry has no prior). */
  increases: number;
  cuts: number;
  /** Rows tagged Initial price — a product's first price. */
  newProducts: number;
  byGroup: Record<ReasonGroupKey, number>;
}

export function priceChangeCounts(rows: PriceChangeRow[]): PriceChangeCounts {
  const byGroup: Record<ReasonGroupKey, number> = { receiving: 0, initial: 0, price: 0, cost: 0, options: 0, other: 0 };
  let increases = 0;
  let cuts = 0;
  for (const r of rows) {
    byGroup[reasonGroup(r.entry.reason).key] += 1;
    if (r.hasPrior && r.priceDelta > 0) increases += 1;
    if (r.hasPrior && r.priceDelta < 0) cuts += 1;
  }
  return { logged: rows.length, increases, cuts, newProducts: byGroup.initial, byGroup };
}
