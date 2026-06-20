import { saleSubtotal, saleTotalDiscount, saleGrandTotal } from '@/domain/entities/Sale';
import type { Sale } from '@/domain/entities/Sale';
import type { SaleItem } from '@/domain/entities/SaleItem';
import type { Product } from '@/domain/entities/Product';
import { PaymentMethod } from '@/domain/enums/PaymentMethod';
import type { DiscountType } from '@/domain/enums/DiscountType';

/** A cart line is a SaleItem snapshot (id = product id until checkout assigns one). */
export type CartLine = SaleItem;

// Reuse the Sale money helpers by shaping a minimal Sale — they read only
// items/laborLines/discountType — so cart and sale math stay single-sourced.
function asSale(lines: CartLine[], discountType: DiscountType): Sale {
  return { items: lines, laborLines: [], discountType } as unknown as Sale;
}

export function cartSubtotal(lines: CartLine[], discountType: DiscountType): number {
  return saleSubtotal(asSale(lines, discountType));
}
export function cartDiscount(lines: CartLine[], discountType: DiscountType): number {
  return saleTotalDiscount(asSale(lines, discountType));
}
export function cartGrandTotal(lines: CartLine[], discountType: DiscountType): number {
  return saleGrandTotal(asSale(lines, discountType)); // labor = 0 this phase
}
export function changeFor(grandTotal: number, amountReceived: number): number {
  return Math.max(0, amountReceived - grandTotal);
}
export function cashTenders(grandTotal: number): Partial<Record<PaymentMethod, number>> {
  return { [PaymentMethod.cash]: grandTotal };
}
/** Product ids whose cart qty exceeds on-hand stock (for the low-stock warning). */
export function lowStockLines(lines: CartLine[], products: Product[]): Set<string> {
  const onHand = new Map(products.map((p) => [p.id, p.quantity]));
  const flagged = new Set<string>();
  for (const l of lines) {
    if (l.quantity > (onHand.get(l.productId) ?? 0)) flagged.add(l.productId);
  }
  return flagged;
}
