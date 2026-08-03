import { saleSubtotal, saleTotalDiscount, saleGrandTotal } from '@/domain/entities/Sale';
import type { Sale } from '@/domain/entities/Sale';
import type { SaleItem } from '@/domain/entities/SaleItem';
import type { Product } from '@/domain/entities/Product';
import type { LaborLine } from '@/domain/entities/LaborLine';
import type { FeeLine } from '@/domain/entities/FeeLine';
import type { DiscountType } from '@/domain/enums/DiscountType';
import { cartLaborSubtotal } from './labor';

/** A cart line is a SaleItem snapshot (id = product id until checkout assigns one). */
export type CartLine = SaleItem;

// Reuse the Sale money helpers by shaping a minimal Sale — they read only
// items/laborLines/feeLines/discountType — so cart and sale math stay
// single-sourced. feeLines defaults to [] — the web POS has no fee-entry UI
// yet, so only a resumed job order's carried fees populate it.
function asSale(lines: CartLine[], discountType: DiscountType, feeLines: FeeLine[] = []): Sale {
  return { items: lines, laborLines: [], feeLines, discountType } as unknown as Sale;
}

export function cartSubtotal(lines: CartLine[], discountType: DiscountType): number {
  return saleSubtotal(asSale(lines, discountType));
}
export function cartDiscount(lines: CartLine[], discountType: DiscountType): number {
  return saleTotalDiscount(asSale(lines, discountType));
}
export function cartGrandTotal(
  lines: CartLine[],
  laborLines: LaborLine[],
  discountType: DiscountType,
  feeLines: FeeLine[] = [],
): number {
  // Parts revenue (labor-0 path) + labor subtotal (described lines only) +
  // carried shop fees (from a resumed job order — full price, no discount).
  return saleGrandTotal(asSale(lines, discountType, feeLines)) + cartLaborSubtotal(laborLines);
}
export function cartFeesTotal(feeLines: FeeLine[]): number {
  return feeLines.reduce((sum, l) => sum + (l.amount || 0), 0);
}
/**
 * Stable identity for a cart line. Plain lines keep the product id, so
 * nothing changes for products without options; an option line appends the
 * option id, because a By 6 and a By 3 of one product are different prices
 * and must not merge.
 */
export function cartLineId(productId: string, optionId: string | null): string {
  return optionId === null ? productId : `${productId}::${optionId}`;
}

/** Product ids whose TOTAL cart quantity exceeds on-hand stock. Summed across
 *  option lines — two lines of one product draw on the same pieces. */
export function lowStockLines(lines: CartLine[], products: Product[]): Set<string> {
  const onHand = new Map(products.map((p) => [p.id, p.quantity]));
  const wanted = new Map<string, number>();
  for (const l of lines) {
    wanted.set(l.productId, (wanted.get(l.productId) ?? 0) + l.quantity);
  }
  const flagged = new Set<string>();
  for (const [productId, qty] of wanted) {
    if (qty > (onHand.get(productId) ?? 0)) flagged.add(productId);
  }
  return flagged;
}
