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
): ClassifiedReceivingRow[] {
  const bySku = new Map<string, Product>();
  for (const p of activeProducts) bySku.set(p.sku.toLowerCase(), p);

  return rows.map((row): ClassifiedReceivingRow => {
    if (row.errors.length > 0) return { row, status: 'error', existing: null };
    if (row.autoGenerateSku) return { row, status: 'new', existing: null };
    const existing = bySku.get(row.sku.toLowerCase()) ?? null;
    if (!existing) return { row, status: 'new', existing: null };
    const costsEqual = Math.abs(existing.cost - row.cost) <= COST_TOLERANCE;
    return { row, status: costsEqual ? 'match' : 'mismatch', existing };
  });
}
