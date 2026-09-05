// The reports guide's rule (§2): EVERY figure derives from one scoped set.
// These assert the invariants literally — the ones the design broke twice.
import { describe, expect, it } from 'vitest';
import { DiscountType, PaymentMethod, SaleStatus } from '@/domain/enums';
import type { Sale, SaleItem } from '@/domain/entities';
import { deriveReportFigures, PAYMENT_COLOR, topProductsBy } from './reportFigures';

function item(o: Partial<SaleItem> & { productId: string; unitPrice: number; unitCost: number; quantity: number }): SaleItem {
  return {
    id: `i-${o.productId}`, sku: `SKU-${o.productId}`, name: `Product ${o.productId}`,
    discountValue: 0, unit: 'pcs', optionId: null, optionLabel: null, optionPieces: null, optionPrice: null,
    ...o,
  };
}

function sale(o: Partial<Sale> = {}): Sale {
  return {
    id: 's', saleNumber: 'SALE-1', items: [], laborLines: [], feeLines: [],
    mechanicId: null, mechanicName: null, motorcycleModel: null, tenders: {},
    discountType: DiscountType.amount, paymentMethod: PaymentMethod.cash,
    amountReceived: 0, changeGiven: 0, status: SaleStatus.completed,
    cashierId: 'c', cashierName: 'C', createdAt: new Date('2026-09-04T08:00:00Z'), updatedAt: null,
    jobOrderId: null, notes: null, voidedAt: null, voidedBy: null, voidedByName: null, voidReason: null,
    ...o,
  };
}

// parts 2×1500=3000 (cost 2440) + labor 1200 → 4200, cash
const s1 = sale({
  id: 's1', paymentMethod: PaymentMethod.cash,
  items: [item({ productId: 'a', unitPrice: 1500, unitCost: 1220, quantity: 2 })],
  laborLines: [{ id: 'l', description: 'Fit', fee: 1200 }],
  mechanicId: 'm1', mechanicName: 'Jeric',
});
// parts 2100+1250=3350 (cost 2155) + labor 900 + fee 50 → 4300, split gcash/maya
const s2 = sale({
  id: 's2', paymentMethod: PaymentMethod.mixed, tenders: { gcash: 4000, maya: 300 },
  items: [
    item({ productId: 'b', unitPrice: 2100, unitCost: 1630, quantity: 1 }),
    item({ productId: 'a', unitPrice: 1250, unitCost: 525, quantity: 1 }),
  ],
  laborLines: [{ id: 'l', description: 'Fit', fee: 900 }],
  feeLines: [{ id: 'f', name: 'Convenience fee', amount: 50, description: null }],
  mechanicId: 'm1', mechanicName: 'Jeric',
});
// voided — must vanish from every figure
const sVoid = sale({
  id: 'sv', status: SaleStatus.voided,
  items: [item({ productId: 'z', unitPrice: 9999, unitCost: 1, quantity: 9 })],
  laborLines: [{ id: 'l', description: 'x', fee: 9999 }],
});

describe('deriveReportFigures — one scoped set', () => {
  const f = deriveReportFigures([s1, s2, sVoid]);

  it('gross sales is PARTS ONLY — labor and fees never land in it; profit = net − cogs', () => {
    expect(f.gross).toBe(6350);
    expect(f.net).toBe(6350);
    expect(f.discounts).toBe(0);
    expect(f.labor).toBe(2100);
    expect(f.fees).toBe(50);
    // what the drawer actually took in — the payment split's denominator
    expect(f.tendered).toBe(6350 + 2100 + 50);
    expect(f.cogs).toBe(2440 + 1630 + 525);
    expect(f.profit).toBe(f.net - f.cogs);
    expect(f.margin).toBeCloseTo(f.profit / f.net, 10);
  });

  it('a discount lowers net (and profit) but not gross', () => {
    const d = deriveReportFigures([
      sale({ items: [item({ productId: 'a', unitPrice: 1000, unitCost: 600, quantity: 1, discountValue: 100 })] }),
    ]);
    expect(d.gross).toBe(1000);
    expect(d.discounts).toBe(100);
    expect(d.net).toBe(900);
    expect(d.profit).toBe(300);
  });

  it('the product table rolls up from the same lines: revenue sums to net, cost to cogs', () => {
    const revenue = f.products.reduce((n, p) => n + p.revenue, 0);
    const cost = f.products.reduce((n, p) => n + p.cost, 0);
    expect(revenue).toBe(f.net);
    expect(cost).toBe(f.cogs);
    // product a = 2×1500 + 1×1250, cost 2×1220 + 525
    const a = f.products.find((p) => p.productId === 'a')!;
    expect(a).toMatchObject({ qty: 3, revenue: 4250, cost: 2965, profit: 1285 });
    expect(a.margin).toBeCloseTo(1285 / 4250, 10);
  });

  it('products sort by profit desc', () => {
    expect(f.products.map((p) => p.productId)).toEqual(['a', 'b']);
  });

  it('the payment split sums to the tendered total, mixed tenders landing in their real buckets', () => {
    const total = f.byPaymentMethod.reduce((n, m) => n + m.amount, 0);
    expect(total).toBe(f.tendered);
    expect(f.byPaymentMethod.map((m) => [m.method, m.amount])).toEqual([
      ['cash', 4200], ['gcash', 4000], ['maya', 300], ['salmon', 0],
    ]);
    expect(f.byPaymentMethod.reduce((n, m) => n + (m.share ?? 0), 0)).toBeCloseTo(1, 10);
  });

  it('counts and averages: sale count, item count, avg order = net parts / count', () => {
    expect(f.count).toBe(2);
    expect(f.itemCount).toBe(4);
    expect(f.avgOrder).toBe(6350 / 2);
  });

  it('labor breakdown groups the same sales', () => {
    expect(f.labor).toBe(f.laborReport.totalLabor);
    expect(f.laborReport.serviceSaleCount).toBe(2);
    expect(f.laborReport.byMechanic).toHaveLength(1);
  });

  it('every figure moves when the set moves', () => {
    const g = deriveReportFigures([s1]);
    expect(g.gross).toBe(3000);
    expect(g.profit).toBe(3000 - 2440);
    expect(g.products).toHaveLength(1);
    expect(g.byPaymentMethod.find((m) => m.method === 'gcash')!.amount).toBe(0);
  });
});

describe('deriveReportFigures — zero case', () => {
  const z = deriveReportFigures([]);
  it('never produces NaN or Infinity: null shares/margin, zero average', () => {
    expect(z.gross).toBe(0);
    expect(z.avgOrder).toBe(0);
    expect(z.margin).toBeNull();
    expect(z.products).toEqual([]);
    for (const m of z.byPaymentMethod) expect(m.share).toBeNull();
  });
  it('a product with zero revenue has a null margin', () => {
    const free = deriveReportFigures([
      sale({ items: [item({ productId: 'q', unitPrice: 0, unitCost: 5, quantity: 1 })] }),
    ]);
    expect(free.products[0].margin).toBeNull();
  });
});

describe('topProductsBy — the Top products lens', () => {
  const f = deriveReportFigures([s1, s2]);
  // a: qty 3, revenue 4250, margin 30.2%   b: qty 1, revenue 2100, margin 22.4%
  const c = deriveReportFigures([
    sale({ items: [item({ productId: 'c', unitPrice: 10, unitCost: 1, quantity: 9 })] }),
  ]).products[0]; // qty 9, revenue 90, margin 90%
  const all = [...f.products, c];

  it('sorts by the chosen lens and caps at five', () => {
    expect(topProductsBy(all, 'qty').map((p) => p.productId)).toEqual(['c', 'a', 'b']);
    expect(topProductsBy(all, 'revenue').map((p) => p.productId)).toEqual(['a', 'b', 'c']);
    expect(topProductsBy(all, 'margin').map((p) => p.productId)).toEqual(['c', 'a', 'b']);
    expect(topProductsBy([...all, ...all, ...all], 'qty')).toHaveLength(5);
  });

  it('a null margin sorts last under the margin lens', () => {
    const free = deriveReportFigures([
      sale({ items: [item({ productId: 'z', unitPrice: 0, unitCost: 5, quantity: 1 })] }),
    ]).products[0];
    expect(topProductsBy([free, ...all], 'margin').map((p) => p.productId)).toEqual(['c', 'a', 'b', 'z']);
  });
});

describe('PAYMENT_COLOR', () => {
  it('maps the four real tenders once: Cash amber, GCash info, Maya pos, Salmon neg', () => {
    expect(PAYMENT_COLOR).toEqual({
      cash: 'var(--accent)', gcash: 'var(--info)', maya: 'var(--pos)', salmon: 'var(--neg)',
    });
  });
});
