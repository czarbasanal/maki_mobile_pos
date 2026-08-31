import type { Product } from '../entities';
import type { ReorderParams } from './computeReorderSuggestions';

/** One candidate line on a buying list. */
export interface BuyingListRow {
  product: Product;
  supplierName: string | null;
  velocityPerDay: number;
  targetStock: number;
  suggestedQty: number;
  /** Nothing on the shelf — listed whatever the sales history says. */
  outOfStock: boolean;
}

/**
 * What to consider buying: everything out of stock, plus everything the
 * movement window says will run out inside the cover period.
 *
 * Out-of-stock parts are included **regardless of velocity**. The velocity
 * engine alone excluded them: a part that sold out early in the window has no
 * sales left to measure, so it scored zero and disappeared exactly when it was
 * most needed.
 *
 * Their quantity falls back to the product's own `reorderLevel` — a field the
 * shop fills in by hand that nothing else reads — and to 1 when that is unset,
 * so a row is never offered at zero. Where there IS sales history, the cover
 * calculation wins: it knows more than a hand-set threshold.
 */
export function buildBuyingListRows(
  products: Product[],
  unitsSold: Map<string, number>,
  params: ReorderParams,
): BuyingListRow[] {
  const out: BuyingListRow[] = [];

  for (const product of products) {
    if (!product.isActive) continue;
    const velocityPerDay = (unitsSold.get(product.id) ?? 0) / params.windowDays;
    const targetStock = Math.ceil(velocityPerDay * params.coverDays);
    const fromVelocity = Math.max(0, targetStock - product.quantity);
    const outOfStock = product.quantity <= 0;

    if (fromVelocity <= 0 && !outOfStock) continue;

    const suggestedQty =
      fromVelocity > 0 ? fromVelocity : Math.max(1, product.reorderLevel ?? 0);

    out.push({
      product,
      supplierName: product.supplierName ?? null,
      velocityPerDay,
      targetStock,
      suggestedQty,
      outOfStock,
    });
  }

  // Out of stock first — "I cannot sell this at all" outranks "I will run low
  // soon" — then grouped by supplier for scanning, then biggest first.
  return out.sort((a, b) => {
    if (a.outOfStock !== b.outOfStock) return a.outOfStock ? -1 : 1;
    const sa = a.supplierName ?? '~~~';
    const sb = b.supplierName ?? '~~~';
    if (sa !== sb) return sa < sb ? -1 : 1;
    return b.suggestedQty - a.suggestedQty;
  });
}
