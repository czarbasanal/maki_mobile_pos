// Inventory status aggregation (spec §5.4) — extracted from the old
// dashboard InventoryStatus component so screens share one definition.
import { getStockStatus, StockStatus, type Product } from '../entities';

export interface InventorySummary {
  total: number;
  inStock: number;
  lowStock: number;
  outOfStock: number;
}

export function summarizeInventory(products: Product[]): InventorySummary {
  const summary: InventorySummary = { total: 0, inStock: 0, lowStock: 0, outOfStock: 0 };
  for (const product of products) {
    if (!product.isActive) continue;
    summary.total += 1;
    const status = getStockStatus(product);
    if (status === StockStatus.inStock) summary.inStock += 1;
    else if (status === StockStatus.lowStock) summary.lowStock += 1;
    else summary.outOfStock += 1;
  }
  return summary;
}

export function sharePercent(part: number, total: number): number {
  if (total <= 0) return 0;
  return Math.round((part / total) * 1000) / 10;
}
