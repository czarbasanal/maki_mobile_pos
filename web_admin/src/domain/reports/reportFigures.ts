// ONE derivation for every report screen (reports guide §2): gross, COGS,
// profit, margin, the payment split, the product rollup and the labor
// breakdown all come from the same scoped sales array, so the Sales, Profit,
// Labor and index cards cannot disagree — the failure the design hit twice.
//
//   gross    = Σ parts subtotal (before discounts)   ← PARTS ONLY, never labor
//   net      = gross − discounts                     labor = Σ labor lines (own track)
//   fees     = Σ fee lines (own track)               tendered = net + labor + fees
//   cogs     = Σ qty × unit cost AT TIME OF SALE (captured on the line)
//   profit   = net − cogs                            margin = profit / net
//
// Labor and shop fees are reported separately and never land in gross sales
// (client decision, 2026-09-05). `tendered` is what the drawer actually
// took in — the only total the payment split (saleEffectiveTenders) sums to.
import { type Sale, saleGrandTotal, saleIsVoided, saleTotalItemCount } from '../entities';
import { type PaymentMethod, paymentMethodDisplayName, realTenderMethods } from '../enums';
import { summarizeSales } from '../sales/summarizeSales';
import { topSellingProducts } from '../sales/topSellingProducts';
import { type LaborReport, summarizeLabor } from '../sales/laborReport';

/** The four real tenders, mapped once (guide §1 Sales): same tones wherever a split appears. */
export const PAYMENT_COLOR: Record<Exclude<PaymentMethod, 'mixed'>, string> = {
  cash: 'var(--accent)',
  gcash: 'var(--info)',
  maya: 'var(--pos)',
  salmon: 'var(--neg)',
};

export interface PaymentSlice {
  method: Exclude<PaymentMethod, 'mixed'>;
  label: string;
  amount: number;
  /** 0–1 share of the tendered total; null when nothing was tendered (render "—", never NaN). */
  share: number | null;
}

export type TopProductLens = 'qty' | 'revenue' | 'margin';

export interface ProductFigures {
  productId: string;
  sku: string;
  name: string;
  qty: number;
  revenue: number;
  cost: number;
  profit: number;
  /** 0–1; null when the product had no revenue. */
  margin: number | null;
}

export interface ReportFigures {
  count: number;
  itemCount: number;
  /** Parts subtotal before discounts. Labor and fees are NOT in here. */
  gross: number;
  /** Parts revenue after discounts — what profit and margin are measured against. */
  net: number;
  discounts: number;
  labor: number;
  fees: number;
  /** net + labor + fees: what was actually tendered, the payment split's total. */
  tendered: number;
  cogs: number;
  profit: number;
  /** profit / net, 0–1; null when net is 0. */
  margin: number | null;
  /** net / count; 0 with no sales. */
  avgOrder: number;
  byPaymentMethod: PaymentSlice[];
  /** Every product sold in range, by profit desc. */
  products: ProductFigures[];
  laborReport: LaborReport;
}

/** The Sales report's "Top products" card: the same product set, sorted by
 *  the chosen lens (a null margin sorts last), capped at five. */
export function topProductsBy(products: ProductFigures[], lens: TopProductLens, limit = 5): ProductFigures[] {
  const key = (p: ProductFigures) =>
    lens === 'qty' ? p.qty : lens === 'revenue' ? p.revenue : (p.margin ?? Number.NEGATIVE_INFINITY);
  return [...products].sort((a, b) => key(b) - key(a)).slice(0, limit);
}

export function deriveReportFigures(sales: Sale[]): ReportFigures {
  const summary = summarizeSales(sales);
  const completed = sales.filter((s) => !saleIsVoided(s));

  const gross = summary.grossAmount;
  const net = summary.netAmount;
  const labor = summary.laborRevenue;
  const fees = summary.feesRevenue;
  const tendered = completed.reduce((n, s) => n + saleGrandTotal(s), 0);
  const cogs = summary.totalCost;
  const profit = net - cogs;
  const count = summary.totalSalesCount;

  const products: ProductFigures[] = topSellingProducts(sales, Number.POSITIVE_INFINITY)
    .map((p) => ({
      productId: p.productId,
      sku: p.sku,
      name: p.name,
      qty: p.quantitySold,
      revenue: p.totalRevenue,
      cost: p.totalCost,
      profit: p.totalProfit,
      margin: p.totalRevenue > 0 ? p.totalProfit / p.totalRevenue : null,
    }))
    .sort((a, b) => b.profit - a.profit);

  const byPaymentMethod: PaymentSlice[] = (realTenderMethods as Array<Exclude<PaymentMethod, 'mixed'>>).map(
    (method) => {
      const amount = summary.byPaymentMethod[method];
      return {
        method,
        label: paymentMethodDisplayName[method],
        amount,
        share: tendered > 0 ? amount / tendered : null,
      };
    },
  );

  return {
    count,
    itemCount: completed.reduce((n, s) => n + saleTotalItemCount(s), 0),
    gross,
    net,
    discounts: summary.totalDiscounts,
    labor,
    fees,
    tendered,
    cogs,
    profit,
    margin: net > 0 ? profit / net : null,
    avgOrder: count > 0 ? net / count : 0,
    byPaymentMethod,
    products,
    laborReport: summarizeLabor(sales),
  };
}
