import type { Product } from '../entities';

export interface ReorderParams {
  windowDays: number;
  coverDays: number;
}

export interface ReorderSuggestion {
  product: Product;
  supplierName: string | null;
  velocityPerDay: number;
  targetStock: number;
  suggestedQty: number;
}

/**
 * Suggests an order quantity per active product purely from stock movement and
 * remaining stock:
 *   velocity = unitsSold(window) / windowDays
 *   target   = ceil(velocity × coverDays)
 *   suggest  = max(0, target − currentStock)
 * Products with no recent sales (velocity 0) or enough stock are excluded.
 * Grouped/sorted by the product's supplier name (no-supplier last), then qty desc.
 */
export function computeReorderSuggestions(
  products: Product[],
  unitsSold: Map<string, number>,
  params: ReorderParams,
): ReorderSuggestion[] {
  const out: ReorderSuggestion[] = [];

  for (const product of products) {
    if (!product.isActive) continue;
    const velocityPerDay = (unitsSold.get(product.id) ?? 0) / params.windowDays;
    const targetStock = Math.ceil(velocityPerDay * params.coverDays);
    const suggestedQty = Math.max(0, targetStock - product.quantity);
    if (suggestedQty <= 0) continue;
    out.push({
      product,
      supplierName: product.supplierName ?? null,
      velocityPerDay,
      targetStock,
      suggestedQty,
    });
  }

  return out.sort((a, b) => {
    const sa = a.supplierName ?? '~~~'; // nulls sort last
    const sb = b.supplierName ?? '~~~';
    if (sa !== sb) return sa < sb ? -1 : 1;
    return b.suggestedQty - a.suggestedQty;
  });
}
