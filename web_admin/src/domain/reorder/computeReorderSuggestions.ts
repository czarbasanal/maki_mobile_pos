import type { Product, Supplier } from '../entities';

export interface ReorderParams {
  windowDays: number;
  coverDays: number;
  defaultLeadDays: number;
}

export interface ReorderSuggestion {
  product: Product;
  supplierName: string | null;
  velocityPerDay: number;
  leadDays: number;
  targetStock: number;
  suggestedQty: number;
}

/**
 * Suggests an order quantity per active product:
 *   velocity = unitsSold(window) / windowDays
 *   target   = ceil(velocity × (leadDays + coverDays))
 *   suggest  = max(0, target − currentStock)
 * Lead time comes from the product's supplier, falling back to defaultLeadDays.
 * Products with no recent sales (velocity 0) or enough stock are excluded.
 * Sorted by supplier name (no-supplier last), then suggested qty desc.
 */
export function computeReorderSuggestions(
  products: Product[],
  unitsSold: Map<string, number>,
  suppliers: Supplier[],
  params: ReorderParams,
): ReorderSuggestion[] {
  const supplierById = new Map(suppliers.map((s) => [s.id, s]));
  const out: ReorderSuggestion[] = [];

  for (const product of products) {
    if (!product.isActive) continue;
    const velocityPerDay = (unitsSold.get(product.id) ?? 0) / params.windowDays;
    const supplier = product.supplierId ? supplierById.get(product.supplierId) : undefined;
    const leadDays = supplier?.leadTimeDays ?? params.defaultLeadDays;
    const targetStock = Math.ceil(velocityPerDay * (leadDays + params.coverDays));
    const suggestedQty = Math.max(0, targetStock - product.quantity);
    if (suggestedQty <= 0) continue;
    out.push({
      product,
      supplierName: supplier?.name ?? product.supplierName ?? null,
      velocityPerDay,
      leadDays,
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
