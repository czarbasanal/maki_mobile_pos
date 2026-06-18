import { describe, expect, it } from 'vitest';
import { computeReorderSuggestions, type ReorderParams } from './computeReorderSuggestions';
import type { Product, Supplier } from '../entities';

function product(over: Partial<Product> = {}): Product {
  return {
    id: 'p1', sku: 'BANGUS', name: 'Bangus', costCode: 'AB', cost: 100, price: 150,
    quantity: 0, reorderLevel: 2, unit: 'kg', supplierId: 'sup-1', supplierName: 'Acme',
    isActive: true, createdAt: new Date(), updatedAt: null, createdBy: null, updatedBy: null,
    createdByName: null, updatedByName: null, searchKeywords: [], baseSku: null,
    variationNumber: null, barcode: null, category: null, imageUrl: null, notes: null, ...over,
  };
}
function supplier(over: Partial<Supplier> = {}): Supplier {
  return {
    id: 'sup-1', name: 'Acme', address: null, contactPerson: null, contactNumber: null,
    alternativeNumber: null, email: null, transactionType: 'cash' as Supplier['transactionType'],
    isActive: true, notes: null, leadTimeDays: null, createdAt: new Date(), updatedAt: null,
    createdBy: null, updatedBy: null, productCount: 0, totalInventoryValue: 0, ...over,
  };
}
const params: ReorderParams = { windowDays: 30, coverDays: 14, defaultLeadDays: 7 };

describe('computeReorderSuggestions', () => {
  it('suggests velocity × (lead + cover) − stock, using supplier lead time', () => {
    // 30 units / 30 days = 1/day. lead 6 + cover 14 = 20 → target 20, stock 5 → suggest 15.
    const out = computeReorderSuggestions(
      [product({ id: 'p1', quantity: 5, supplierId: 'sup-1' })],
      new Map([['p1', 30]]),
      [supplier({ id: 'sup-1', leadTimeDays: 6 })],
      params,
    );
    expect(out).toHaveLength(1);
    expect(out[0]).toMatchObject({ leadDays: 6, targetStock: 20, suggestedQty: 15, velocityPerDay: 1 });
  });

  it('uses defaultLeadDays when the supplier has no lead time', () => {
    const out = computeReorderSuggestions(
      [product({ id: 'p1', quantity: 0 })],
      new Map([['p1', 30]]),
      [supplier({ id: 'sup-1', leadTimeDays: null })],
      params,
    );
    expect(out[0]).toMatchObject({ leadDays: 7, suggestedQty: 21 });
  });

  it('rounds the target up (ceil)', () => {
    // 10 / 30 = 0.333/day × 21 = 7.0 → ceil 7; stock 0 → 7.
    const out = computeReorderSuggestions(
      [product({ id: 'p1', quantity: 0, supplierId: null, supplierName: null })],
      new Map([['p1', 10]]),
      [],
      params,
    );
    expect(out[0]).toMatchObject({ targetStock: 7, suggestedQty: 7, supplierName: null });
  });

  it('excludes zero-velocity products and already-stocked products', () => {
    const out = computeReorderSuggestions(
      [
        product({ id: 'dead', quantity: 0 }),
        product({ id: 'full', quantity: 999 }),
      ],
      new Map([['full', 30]]),
      [supplier()],
      params,
    );
    expect(out).toHaveLength(0);
  });

  it('skips inactive products and sorts by supplier then qty desc', () => {
    const out = computeReorderSuggestions(
      [
        product({ id: 'p1', quantity: 0, supplierId: 'b', supplierName: 'Beta' }),
        product({ id: 'p2', quantity: 0, supplierId: 'a', supplierName: 'Acme' }),
        product({ id: 'gone', quantity: 0, isActive: false }),
      ],
      new Map([['p1', 30], ['p2', 60], ['gone', 60]]),
      [supplier({ id: 'a', name: 'Acme' }), supplier({ id: 'b', name: 'Beta' })],
      params,
    );
    expect(out.map((s) => s.product.id)).toEqual(['p2', 'p1']);
  });
});
