// Mirror of lib/domain/entities/fee_line_entity.dart. Stored INLINE on the
// sale document's `feeLines` array. Shop fees belong to the SHOP (management),
// are never discounted, and have zero cost — a third revenue track beside
// parts and labor.
export interface FeeLine {
  id: string;
  name: string;
  amount: number;
  /** Required only for the "Charge Item" fee (what's being charged);
   *  null for every other fee and for legacy lines. */
  description: string | null;
}

/** The one fee whose dialog requires a cashier-entered description. */
export const CHARGE_ITEM_FEE_NAME = 'Charge Item';

/** Itemized label: `"name — description"` when a description is set;
 *  otherwise just the name (mirrors FeeLineEntity.displayLabel). */
export function feeLineDisplayLabel(line: FeeLine): string {
  const d = line.description?.trim();
  return d ? `${line.name} — ${d}` : line.name;
}
