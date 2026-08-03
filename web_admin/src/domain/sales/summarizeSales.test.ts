import { describe, expect, it } from 'vitest';
import { DiscountType, PaymentMethod, SaleStatus } from '../enums';
import { type Sale } from '../entities';
import { summarizeSales } from './summarizeSales';

function sale(overrides: Partial<Sale> = {}): Sale {
  return {
    id: 's',
    saleNumber: 'S',
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

describe('summarizeSales', () => {
  it('parts-only sale: top-line is parts, labor track is zero', () => {
    const s = summarizeSales([sale()]);
    expect(s.totalSalesCount).toBe(1);
    expect(s.grossAmount).toBe(200);
    expect(s.netAmount).toBe(200);
    expect(s.totalCost).toBe(120);
    expect(s.totalProfit).toBe(80);
    expect(s.laborRevenue).toBe(0);
    expect(s.byPaymentMethod.cash).toBe(200);
  });

  it('labor sale: parts-only top-line + labor track; cash bucket is labor-inclusive', () => {
    const s = summarizeSales([
      sale({ laborLines: [{ id: 'l1', description: 'Tune-up', fee: 450 }] }),
    ]);
    // Parts-only top-line (NOT 650).
    expect(s.grossAmount).toBe(200);
    expect(s.netAmount).toBe(200);
    expect(s.totalProfit).toBe(80);
    // Labor track.
    expect(s.laborRevenue).toBe(450);
    expect(s.laborProfit).toBe(450);
    // Cash bucket holds the whole labor-inclusive grandTotal.
    expect(s.byPaymentMethod.cash).toBe(650);
    // Reconciliation identity.
    const tenderTotal = Object.values(s.byPaymentMethod).reduce((a, b) => a + b, 0);
    expect(tenderTotal).toBe(s.netAmount + s.laborRevenue); // 650
  });

  it('fee sale: parts-only top-line + fees track; fees roll up separately from labor', () => {
    const s = summarizeSales([
      sale({ feeLines: [{ id: 'f1', name: 'Electric charge', amount: 150 }] }),
    ]);
    // Parts-only top-line (NOT 350).
    expect(s.grossAmount).toBe(200);
    expect(s.netAmount).toBe(200);
    expect(s.totalProfit).toBe(80);
    // Fees track.
    expect(s.feesRevenue).toBe(150);
    expect(s.laborRevenue).toBe(0);
    // Cash bucket holds the whole fee-inclusive grandTotal.
    expect(s.byPaymentMethod.cash).toBe(350);
  });

  it('mixed-tender sale splits into real buckets; mixed never holds money', () => {
    const s = summarizeSales([
      sale({ paymentMethod: PaymentMethod.mixed, tenders: { cash: 120, gcash: 80 } }),
    ]);
    expect(s.byPaymentMethod.cash).toBe(120);
    expect(s.byPaymentMethod.gcash).toBe(80);
    expect(s.byPaymentMethod.mixed).toBe(0);
  });

  it('excludes voided sales from money but counts them', () => {
    const s = summarizeSales([sale(), sale({ status: SaleStatus.voided })]);
    expect(s.totalSalesCount).toBe(1);
    expect(s.voidedSalesCount).toBe(1);
    expect(s.netAmount).toBe(200);
  });

  it('excludes voided sales fees from the feesRevenue track', () => {
    const s = summarizeSales([
      sale({ feeLines: [{ id: 'f1', name: 'Electric charge', amount: 150 }] }),
      sale({
        status: SaleStatus.voided,
        feeLines: [{ id: 'f2', name: 'Cleanup', amount: 999 }],
      }),
    ]);
    expect(s.feesRevenue).toBe(150);
  });
});
