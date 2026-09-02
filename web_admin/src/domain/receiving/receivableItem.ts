import type { Product } from '../entities';
import type { SellingOption } from '../entities/SellingOption';
import type { ClassifiedReceivingRow } from './classifyReceivingRows';
import { composeAutoSku } from '../products/sku';

/** A line ready to be received, normalized so both the CSV path (classified
 *  rows) and a resumed draft (persisted items) map into the same shape that
 *  `planReceive` consumes. `ref` labels the source line for error
 *  reporting (the CSV row number, or a 0-based index for manual entry). */
export type ReceivableItem = { ref: string | number } & (
  | { kind: 'match'; product: Product; quantity: number }
  | {
      kind: 'mismatch';
      product: Product;
      quantity: number;
      cost: number;
      /** Selling price for the spawned variation; null inherits the base's. */
      price: number | null;
    }
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
      /** Set when auto-SKU is category-driven: `sku` is then only a peeked
       *  preview, and the executing transaction re-scans from it under this
       *  code. Null = legacy name-based generation (CSV rows). */
      autoSkuCategoryCode: string | null;
      barcodes: string[];
      notes: string | null;
      sellingOptions: SellingOption[];
    }
);

export function classifiedToReceivable(
  row: ClassifiedReceivingRow,
  /** Category name → auto-SKU code, for GENERATE rows. Classification already
   *  rejected auto rows whose category has no code. */
  categoryCodes: ReadonlyMap<string, string>,
): ReceivableItem | null {
  if (row.status === 'error') return null;
  if (row.status === 'duplicate-name') {
    // The sole caller resolves a duplicate-name row (into match, mismatch or
    // new) BEFORE it ever reaches here — that's a runtime invariant, not a
    // type one, so make a violation loud instead of silently falling through
    // to kind:'new' below.
    throw new Error(
      `Row ${row.row.rowNumber}: unresolved duplicate-name row reached classifiedToReceivable — resolve it first.`,
    );
  }
  const r = row.row;
  if (row.status === 'match' && row.existing) {
    return { ref: r.rowNumber, kind: 'match', product: row.existing, quantity: r.quantity };
  }
  if (row.status === 'mismatch' && row.existing) {
    return {
      ref: r.rowNumber, kind: 'mismatch', product: row.existing,
      quantity: r.quantity, cost: r.cost,
      // The CSV's price column applies to the variation this row spawns.
      // 0 means "inherit the base's price" — the column is mandatory, and
      // old templates filled it with 0 on mismatch rows (it used to be
      // ignored here); a ₱0 selling price is never what was meant.
      price: r.price > 0 ? r.price : null,
    };
  }
  const code = r.autoGenerateSku && r.category != null
      ? categoryCodes.get(r.category) ?? null
      : null;
  return {
    ref: r.rowNumber,
    kind: 'new',
    // Auto rows get a pattern-matching PLACEHOLDER — create()'s transaction
    // scans from the registry and allocates the real sequence. Sequence 1 is
    // deliberate: the scan starts at max(placeholder, registry.nextSequence).
    sku: code != null ? composeAutoSku(code, 1) : r.sku,
    autoGenerateSku: r.autoGenerateSku,
    name: r.name, category: r.category, unit: r.unit, cost: r.cost, price: r.price,
    quantity: r.quantity, reorderLevel: r.reorderLevel,
    autoSkuCategoryCode: code,
    // CSV rows carry none of the modal-only fields.
    barcodes: [], notes: null, sellingOptions: [],
  };
}
