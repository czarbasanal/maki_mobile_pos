import { describe, expect, it } from 'vitest';
import { DiscountType, PaymentMethod, SaleStatus } from '../enums';
import {
  type Sale,
  saleEffectiveTenders,
  saleFeesTotal,
  saleGrandTotal,
  saleLaborProfit,
  saleLaborRevenue,
  saleLaborSubtotal,
  salePartsProfit,
  salePartsRevenue,
  salePartsSubtotal,
  saleTotalCost,
  saleTotalProfit,
} from './Sale';

function baseSale(overrides: Partial<Sale> = {}): Sale {
  return {
    id: 's1',
    saleNumber: 'S-1',
    items: [
      {
        id: 'i1',
        productId: 'p1',
        sku: 'SKU-1',
        name: 'Brake Pad',
        unitPrice: 100,
        unitCost: 60,
        quantity: 2,
        discountValue: 0,
        unit: 'pcs',
        optionId: null,
        optionLabel: null,
        optionPieces: null,
        optionPrice: null,
      },
    ],
    laborLines: [],
    feeLines: [],
    mechanicId: null,
    mechanicName: null,
    discountType: DiscountType.amount,
    paymentMethod: PaymentMethod.cash,
    tenders: {},
    amountReceived: 200,
    changeGiven: 0,
    status: SaleStatus.completed,
    cashierId: 'c1',
    cashierName: 'Cashier',
    createdAt: new Date('2026-05-30T10:00:00Z'),
    updatedAt: null,
    jobOrderId: null,
    notes: null,
    voidedAt: null,
    voidedBy: null,
    voidedByName: null,
    voidReason: null,
    ...overrides,
  };
}

describe('Sale money math (labor-aware)', () => {
  it('parts-only sale: grandTotal equals parts revenue, no labor', () => {
    const s = baseSale();
    expect(salePartsSubtotal(s)).toBe(200);
    expect(salePartsRevenue(s)).toBe(200);
    expect(saleLaborSubtotal(s)).toBe(0);
    expect(saleGrandTotal(s)).toBe(200);
    expect(saleTotalCost(s)).toBe(120);
    expect(salePartsProfit(s)).toBe(80);
    expect(saleTotalProfit(s)).toBe(80);
  });

  it('labor raises grandTotal/profit but not the parts figures', () => {
    const s = baseSale({
      laborLines: [
        { id: 'l1', description: 'Tune-up', fee: 300 },
        { id: 'l2', description: 'Bleed', fee: 150 },
      ],
    });
    expect(salePartsRevenue(s)).toBe(200); // unchanged
    expect(saleLaborSubtotal(s)).toBe(450);
    expect(saleLaborRevenue(s)).toBe(450);
    expect(saleGrandTotal(s)).toBe(650); // 200 + 450
    expect(salePartsProfit(s)).toBe(80); // parts only
    expect(saleLaborProfit(s)).toBe(450);
    expect(saleTotalProfit(s)).toBe(530); // 80 + 450
  });

  it('effectiveTenders falls back to grandTotal on the payment method', () => {
    const s = baseSale({
      laborLines: [{ id: 'l1', description: 'x', fee: 300 }],
    });
    expect(saleEffectiveTenders(s)).toEqual({ cash: 500 }); // 200 + 300
  });

  it('effectiveTenders uses the explicit tenders map for a mixed sale', () => {
    const s = baseSale({
      paymentMethod: PaymentMethod.mixed,
      tenders: { cash: 120, gcash: 80 },
    });
    expect(saleEffectiveTenders(s)).toEqual({ cash: 120, gcash: 80 });
  });

  it('saleFeesTotal sums fee lines; saleGrandTotal includes them', () => {
    const s = baseSale({
      items: [
        {
          id: 'i1',
          productId: 'p1',
          sku: 'SKU-1',
          name: 'Brake Pad',
          unitPrice: 1000,
          unitCost: 700,
          quantity: 1,
          discountValue: 100,
          unit: 'pcs',
          optionId: null,
          optionLabel: null,
          optionPieces: null,
          optionPrice: null,
        },
      ],
      laborLines: [{ id: 'l1', description: 'Tune-up', fee: 300 }],
      feeLines: [{ id: 'f1', name: 'Electric charge', amount: 150 }],
    });
    expect(saleFeesTotal(s)).toBe(150);
    expect(saleGrandTotal(s)).toBe(1350); // 900 parts + 300 labor + 150 fees
    expect(saleTotalProfit(s)).toBe(500); // 200 parts profit + 300 labor profit, unchanged by fees
  });

  it('legacy sale without feeLines totals as before', () => {
    const s = baseSale();
    expect(saleFeesTotal(s)).toBe(0);
    expect(saleGrandTotal(s)).toBe(200); // unchanged: no labor, no fees
  });
});
