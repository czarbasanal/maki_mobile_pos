// Client-side "top selling products" rollup. Mirrors the Dart ProductSalesData
// from lib/domain/usecases/reports/get_top_selling_usecase.dart.

import {
  type Sale,
  saleIsVoided,
  saleItemNet,
  saleItemTotalCost,
} from '../entities';
import { DiscountType } from '../enums';

export interface ProductSalesData {
  productId: string;
  sku: string;
  name: string;
  quantitySold: number;
  totalRevenue: number;
  totalCost: number;
  totalProfit: number;
}

export function topSellingProducts(
  sales: Sale[],
  limit = 10,
): ProductSalesData[] {
  const byProduct = new Map<string, ProductSalesData>();

  for (const sale of sales) {
    if (saleIsVoided(sale)) continue;
    const isPercentage = sale.discountType === DiscountType.percentage;
    for (const it of sale.items) {
      const entry =
        byProduct.get(it.productId) ??
        {
          productId: it.productId,
          sku: it.sku,
          name: it.name,
          quantitySold: 0,
          totalRevenue: 0,
          totalCost: 0,
          totalProfit: 0,
        };
      entry.quantitySold += it.quantity;
      entry.totalRevenue += saleItemNet(it, isPercentage);
      entry.totalCost += saleItemTotalCost(it);
      entry.totalProfit = entry.totalRevenue - entry.totalCost;
      byProduct.set(it.productId, entry);
    }
  }

  return [...byProduct.values()]
    .sort((a, b) => b.totalRevenue - a.totalRevenue)
    .slice(0, limit);
}
