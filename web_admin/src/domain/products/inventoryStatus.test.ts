import { describe, expect, it } from 'vitest';
import { sharePercent, summarizeInventory } from './inventoryStatus';
import type { Product } from '../entities';

function fakeProduct(overrides: Partial<Product>): Product {
  return {
    id: 'p', sku: 'S', name: 'N', costCode: '', cost: 0, price: 0, quantity: 10,
    reorderLevel: 2, unit: 'pcs', supplierId: null, supplierName: null, isActive: true,
    createdAt: new Date(), updatedAt: null, createdBy: null, updatedBy: null,
    createdByName: null, updatedByName: null, searchKeywords: [], baseSku: null,
    variationNumber: null, barcodes: [], sellingOptions: [], category: null,
    imageUrl: null, notes: null, tagIds: [], ...overrides,
  };
}

describe('summarizeInventory', () => {
  it('counts stock statuses and skips inactive products', () => {
    const summary = summarizeInventory([
      fakeProduct({ quantity: 10, reorderLevel: 2 }),   // in stock
      fakeProduct({ quantity: 2, reorderLevel: 2 }),    // low (qty <= reorder, > 0)
      fakeProduct({ quantity: 0 }),                     // out
      fakeProduct({ quantity: 0, isActive: false }),    // skipped
    ]);
    expect(summary).toEqual({ total: 3, inStock: 1, lowStock: 1, outOfStock: 1 });
  });
});

describe('sharePercent', () => {
  it('rounds to one decimal', () => expect(sharePercent(1, 3)).toBe(33.3));
  it('is 0 for an empty total', () => expect(sharePercent(1, 0)).toBe(0));
});
