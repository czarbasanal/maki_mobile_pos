// Mirror of lib/data/repositories/sale_repository_impl.dart getSalesSummary.
// The merchandise top-line stays PARTS-ONLY; labor rides a parallel track;
// payment buckets are labor-inclusive (the drawer physically holds labor cash).

import {
  type Sale,
  saleEffectiveTenders,
  saleIsVoided,
  saleLaborRevenue,
  salePartsRevenue,
  salePartsSubtotal,
  saleTotalCost,
  saleTotalDiscount,
} from '../entities';
import { type PaymentMethod, realTenderMethods } from '../enums';

export interface SalesSummary {
  totalSalesCount: number;
  voidedSalesCount: number;
  grossAmount: number;
  totalDiscounts: number;
  netAmount: number;
  totalCost: number;
  totalProfit: number;
  laborRevenue: number;
  laborProfit: number;
  byPaymentMethod: Record<PaymentMethod, number>;
  averageSaleAmount: number;
  profitMargin: number;
}

export function summarizeSales(sales: Sale[]): SalesSummary {
  const completed = sales.filter((s) => !saleIsVoided(s));
  const voidedCount = sales.length - completed.length;

  const byPaymentMethod: Record<PaymentMethod, number> = {
    cash: 0,
    gcash: 0,
    maya: 0,
    salmon: 0,
    mixed: 0, // a label, never a bucket — always stays 0
  };

  let grossAmount = 0;
  let totalDiscounts = 0;
  let netAmount = 0;
  let totalCost = 0;
  let laborRevenue = 0;

  for (const s of completed) {
    grossAmount += salePartsSubtotal(s);
    totalDiscounts += saleTotalDiscount(s);
    netAmount += salePartsRevenue(s);
    totalCost += saleTotalCost(s);
    laborRevenue += saleLaborRevenue(s);
    const eff = saleEffectiveTenders(s);
    for (const method of realTenderMethods) {
      byPaymentMethod[method] += eff[method] ?? 0;
    }
  }

  const totalProfit = netAmount - totalCost;
  const count = completed.length;

  return {
    totalSalesCount: count,
    voidedSalesCount: voidedCount,
    grossAmount,
    totalDiscounts,
    netAmount,
    totalCost,
    totalProfit,
    laborRevenue,
    laborProfit: laborRevenue, // labor has zero cost
    byPaymentMethod,
    averageSaleAmount: count === 0 ? 0 : netAmount / count,
    profitMargin: netAmount === 0 ? 0 : (totalProfit / netAmount) * 100,
  };
}
