// What a receiving row shows in its SKU cell before the code exists.
//
// An auto-SKU row has no real SKU until the receive transaction scans the
// category registry and allocates one. Anything shown before that is a guess:
// the value carried on the row is only a FLOOR for that scan, and every row
// added in one sitting carries the same one — which is why three new products
// in a category all used to display an identical code.
//
// So a row awaiting allocation shows no code at all. The real SKU appears the
// moment the receiving is saved.
import { displaySku } from '@/domain/products/sku';

export const PENDING_SKU_LABEL = 'Assigned when saved';

/**
 * The SKU cell's text. `awaitingAllocation` is true for a new product whose
 * SKU is auto-generated from its category; a typed SKU is shown verbatim.
 */
export function skuCellText(sku: string, awaitingAllocation: boolean): string {
  return awaitingAllocation ? PENDING_SKU_LABEL : displaySku(sku);
}
