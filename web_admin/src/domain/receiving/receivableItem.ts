import type { Product } from '../entities';
import type { ClassifiedReceivingRow } from './classifyReceivingRows';

/** A line ready to be received, normalized so both the CSV path (classified
 *  rows) and a resumed draft (persisted items) map into the same shape that
 *  `applyReceivedItems` consumes. `ref` labels the source line for error
 *  reporting (the CSV row number, or a 0-based index for manual entry). */
export type ReceivableItem = { ref: string | number } & (
  | { kind: 'match'; product: Product; quantity: number }
  | { kind: 'mismatch'; product: Product; quantity: number; cost: number }
  | {
      kind: 'new';
      sku: string;
      autoGenerateSku: boolean;
      name: string;
      category: string | null;
      unit: string;
      cost: number;
      price: number;
      quantity: number;
      reorderLevel: number;
    }
);

export function classifiedToReceivable(row: ClassifiedReceivingRow): ReceivableItem | null {
  if (row.status === 'error') return null;
  const r = row.row;
  if (row.status === 'match' && row.existing) {
    return { ref: r.rowNumber, kind: 'match', product: row.existing, quantity: r.quantity };
  }
  if (row.status === 'mismatch' && row.existing) {
    return {
      ref: r.rowNumber, kind: 'mismatch', product: row.existing,
      quantity: r.quantity, cost: r.cost,
    };
  }
  return {
    ref: r.rowNumber, kind: 'new', sku: r.sku, autoGenerateSku: r.autoGenerateSku,
    name: r.name, category: r.category, unit: r.unit, cost: r.cost, price: r.price,
    quantity: r.quantity, reorderLevel: r.reorderLevel,
  };
}
