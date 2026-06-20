import { describe, expect, it } from 'vitest';
import { cartGrandTotal, changeFor, cashTenders, lowStockLines } from './cart';
import { DiscountType } from '@/domain/enums/DiscountType';
import { PaymentMethod } from '@/domain/enums/PaymentMethod';
import type { Product } from '@/domain/entities';
import type { CartLine } from './cart';

const line = (over: Partial<CartLine> = {}): CartLine => ({
  id: 'p1', productId: 'p1', sku: 'A', name: 'A',
  unitPrice: 100, unitCost: 60, quantity: 1, discountValue: 0, unit: 'pcs', ...over,
});

describe('cartGrandTotal', () => {
  it('sums net of per-line amount discounts', () => {
    expect(cartGrandTotal([line({ quantity: 2 }), line({ productId: 'p2', discountValue: 20 })], DiscountType.amount))
      .toBe(200 + 80);
  });
  it('applies percentage discounts', () => {
    expect(cartGrandTotal([line({ discountValue: 10 })], DiscountType.percentage)).toBe(90);
  });
});

describe('changeFor', () => {
  it('is received minus total, floored at 0', () => {
    expect(changeFor(100, 150)).toBe(50);
    expect(changeFor(100, 100)).toBe(0);
    expect(changeFor(100, 80)).toBe(0);
  });
});

describe('cashTenders', () => {
  it('puts the whole total in the cash bucket', () => {
    expect(cashTenders(250)).toEqual({ [PaymentMethod.cash]: 250 });
  });
});

describe('lowStockLines', () => {
  it('flags lines whose qty exceeds on-hand', () => {
    const products = [{ id: 'p1', quantity: 1 }, { id: 'p2', quantity: 5 }] as Product[];
    const flagged = lowStockLines([line({ quantity: 3 }), line({ productId: 'p2', quantity: 2 })], products);
    expect([...flagged]).toEqual(['p1']);
  });
});
