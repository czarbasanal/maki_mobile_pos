import { saleIsVoided, type Sale } from '../entities';

/** Total units sold per productId across the given (non-voided) sales. */
export function unitsSoldByProduct(sales: Sale[]): Map<string, number> {
  const m = new Map<string, number>();
  for (const sale of sales) {
    if (saleIsVoided(sale)) continue;
    for (const it of sale.items) {
      m.set(it.productId, (m.get(it.productId) ?? 0) + it.quantity);
    }
  }
  return m;
}
