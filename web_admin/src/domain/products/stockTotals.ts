import type { Product } from '@/domain/entities';

export interface StockTotals {
  cost: number;
  retail: number;
  profit: number;
}

/** Inventory valuation over whatever list the screen is rendering. */
export function stockTotals(
  products: Pick<Product, 'cost' | 'price' | 'quantity'>[],
): StockTotals {
  let cost = 0;
  let retail = 0;
  for (const p of products) {
    cost += p.cost * p.quantity;
    retail += p.price * p.quantity;
  }
  return { cost, retail, profit: retail - cost };
}
