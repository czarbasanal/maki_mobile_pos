import type { Product } from '../entities';
import type { ParsedReceivingRow } from './parseReceivingRows';

export type ReceivingRowStatus = 'new' | 'match' | 'mismatch' | 'error';

export interface ClassifiedReceivingRow {
  row: ParsedReceivingRow;
  status: ReceivingRowStatus;
  existing: Product | null;
}

const COST_TOLERANCE = 0.01;

export function classifyReceivingRows(
  rows: ParsedReceivingRow[],
  activeProducts: Product[],
  /** Active product-category name → auto-SKU code. GENERATE rows resolve their
   *  SKU through this; a row whose category has no code is REJECTED rather
   *  than name-generated — the retired random-suffix format must not keep
   *  leaking into the catalog through the CSV door. */
  categoryCodes: ReadonlyMap<string, string>,
): ClassifiedReceivingRow[] {
  const bySku = new Map<string, Product>();
  for (const p of activeProducts) bySku.set(p.sku.toLowerCase(), p);

  return rows.map((row): ClassifiedReceivingRow => {
    if (row.errors.length > 0) return { row, status: 'error', existing: null };
    if (row.autoGenerateSku) {
      const code = row.category != null ? categoryCodes.get(row.category) : undefined;
      if (code === undefined) {
        return {
          row: {
            ...row,
            errors: [
              ...row.errors,
              row.category == null
                ? 'GENERATE needs a category with a code — add a coded category or type a SKU.'
                : `Category "${row.category}" has no code — GENERATE cannot make a SKU for it. Give the category a code or type a SKU.`,
            ],
          },
          status: 'error',
          existing: null,
        };
      }
      return { row, status: 'new', existing: null };
    }
    const existing = bySku.get(row.sku.toLowerCase()) ?? null;
    if (!existing) return { row, status: 'new', existing: null };
    const costsEqual = Math.abs(existing.cost - row.cost) <= COST_TOLERANCE;
    return { row, status: costsEqual ? 'match' : 'mismatch', existing };
  });
}
