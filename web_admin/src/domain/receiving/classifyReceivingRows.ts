import { productDuplicateKey } from '@/domain/products/nameKey';
import type { Product } from '../entities';
import type { ParsedReceivingRow } from './parseReceivingRows';

export type ReceivingRowStatus = 'new' | 'match' | 'mismatch' | 'error' | 'duplicate-name';

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
  const byNameKey = new Map<string, Product>();
  for (const p of activeProducts) {
    bySku.set(p.sku.toLowerCase(), p);
    // A cost variation inherits its base's name/category, so it carries the
    // SAME duplicate key — skip it so a base is always preferred over a
    // variation. First writer wins among remaining bases: with duplicates
    // already in the catalog, the report only needs to name one of them.
    if (p.baseSku != null) continue;
    const key = productDuplicateKey(p.name, p.category);
    if (!byNameKey.has(key)) byNameKey.set(key, p);
  }

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
      const nameMatch = byNameKey.get(productDuplicateKey(row.name, row.category)) ?? null;
      if (nameMatch) return { row, status: 'duplicate-name', existing: nameMatch };
      return { row, status: 'new', existing: null };
    }
    const existing = bySku.get(row.sku.toLowerCase()) ?? null;
    if (!existing) return { row, status: 'new', existing: null };
    const costsEqual = Math.abs(existing.cost - row.cost) <= COST_TOLERANCE;
    return { row, status: costsEqual ? 'match' : 'mismatch', existing };
  });
}

/** How the operator resolved a `duplicate-name` row: fold it into the
 *  matched product as a variation (the default), or let it through as a
 *  genuinely new product. */
export type DuplicateNameResolution = 'variation' | 'new';

/**
 * Applies the operator's choice for a `duplicate-name` row. "variation"
 * re-runs the SAME cost-tolerance check a typed SKU would get against
 * `classified.existing`, so it lands on `match`/`mismatch` and flows through
 * the existing cost-mismatch/variation machinery unchanged. "new" clears the
 * name match and lets the row create a fresh product, exactly as an
 * un-flagged GENERATE row would. A no-op on any other status.
 */
export function resolveDuplicateName(
  classified: ClassifiedReceivingRow,
  resolution: DuplicateNameResolution,
): ClassifiedReceivingRow {
  if (classified.status !== 'duplicate-name' || !classified.existing) return classified;
  if (resolution === 'new') return { ...classified, status: 'new', existing: null };
  const existing = classified.existing;
  const costsEqual = Math.abs(existing.cost - classified.row.cost) <= COST_TOLERANCE;
  return { ...classified, status: costsEqual ? 'match' : 'mismatch', existing };
}
