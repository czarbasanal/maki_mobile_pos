import { describe, expect, it } from 'vitest';
import { computeReorderSuggestions, type ReorderParams } from './computeReorderSuggestions';
import type { Product } from '../entities';

function product(over: Partial<Product> = {}): Product {
  return {
    id: 'p1', sku: 'BANGUS', name: 'Bangus', costCode: 'AB', cost: 100, price: 150,
    quantity: 0, reorderLevel: 2, unit: 'kg', supplierId: 'sup-1', supplierName: 'Acme',
    isActive: true, createdAt: new Date(), updatedAt: null, createdBy: null, updatedBy: null,
    createdByName: null, updatedByName: null, searchKeywords: [], baseSku: null,
    variationNumber: null, barcodes: [], category: null, imageUrl: null, notes: null, ...over,
  };
}
const params: ReorderParams = { windowDays: 30, coverDays: 14 };

describe('computeReorderSuggestions', () => {
  it('suggests velocity × cover − stock', () => {
    // 30 units / 30 days = 1/day × 14 cover = target 14, stock 5 → suggest 9.
    const out = computeReorderSuggestions(
      [product({ id: 'p1', quantity: 5 })],
      new Map([['p1', 30]]),
      params,
    );
    expect(out).toHaveLength(1);
    expect(out[0]).toMatchObject({ targetStock: 14, suggestedQty: 9, velocityPerDay: 1 });
  });

  it('rounds the target up (ceil)', () => {
    // 10 / 30 = 0.333/day × 14 = 4.66 → ceil 5; stock 0 → 5.
    const out = computeReorderSuggestions(
      [product({ id: 'p1', quantity: 0 })],
      new Map([['p1', 10]]),
      params,
    );
    expect(out[0]).toMatchObject({ targetStock: 5, suggestedQty: 5 });
  });

  it('excludes zero-velocity products and already-stocked products', () => {
    const out = computeReorderSuggestions(
      [product({ id: 'dead', quantity: 0 }), product({ id: 'full', quantity: 999 })],
      new Map([['full', 30]]),
      params,
    );
    expect(out).toHaveLength(0);
  });

  it('skips inactive products and sorts by supplier name then qty desc', () => {
    const out = computeReorderSuggestions(
      [
        product({ id: 'p1', quantity: 0, supplierName: 'Beta' }),
        product({ id: 'p2', quantity: 0, supplierName: 'Acme' }),
        product({ id: 'gone', quantity: 0, isActive: false }),
      ],
      new Map([['p1', 30], ['p2', 60], ['gone', 60]]),
      params,
    );
    expect(out.map((s) => s.product.id)).toEqual(['p2', 'p1']); // Acme before Beta; gone skipped
    expect(out[0].supplierName).toBe('Acme');
  });

  it('keeps a null supplier name (No supplier bucket)', () => {
    const out = computeReorderSuggestions(
      [product({ id: 'p1', quantity: 0, supplierId: null, supplierName: null })],
      new Map([['p1', 30]]),
      params,
    );
    expect(out[0].supplierName).toBeNull();
  });
});
