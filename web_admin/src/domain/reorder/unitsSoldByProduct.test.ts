import { describe, expect, it } from 'vitest';
import { unitsSoldByProduct } from './unitsSoldByProduct';
import { DiscountType, PaymentMethod, SaleStatus } from '../enums';
import type { Sale } from '../entities';

function sale(over: Partial<Sale> = {}): Sale {
  return {
    id: 's', saleNumber: 'S', items: [], laborLines: [], mechanicId: null, mechanicName: null,
    discountType: DiscountType.amount, paymentMethod: PaymentMethod.cash, tenders: {},
    amountReceived: 0, changeGiven: 0, status: SaleStatus.completed, cashierId: 'c1',
    cashierName: 'Cashier', createdAt: new Date('2026-06-01T10:00:00Z'), updatedAt: null,
    draftId: null, notes: null, voidedAt: null, voidedBy: null, voidedByName: null,
    voidReason: null, ...over,
  };
}
function item(productId: string, qty: number) {
  return {
    id: `${productId}-${qty}`, productId, sku: productId, name: productId,
    unitPrice: 10, unitCost: 5, quantity: qty, discountValue: 0, unit: 'pcs',
  };
}

describe('unitsSoldByProduct', () => {
  it('sums quantity per product across sales', () => {
    const m = unitsSoldByProduct([
      sale({ items: [item('p1', 3), item('p2', 1)] }),
      sale({ items: [item('p1', 2)] }),
    ]);
    expect(m.get('p1')).toBe(5);
    expect(m.get('p2')).toBe(1);
  });

  it('excludes voided sales', () => {
    const m = unitsSoldByProduct([
      sale({ items: [item('p1', 4)] }),
      sale({ status: SaleStatus.voided, items: [item('p1', 99)] }),
    ]);
    expect(m.get('p1')).toBe(4);
  });

  it('returns an empty map for no sales', () => {
    expect(unitsSoldByProduct([]).size).toBe(0);
  });
});
