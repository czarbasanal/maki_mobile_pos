import { describe, expect, it } from 'vitest';
import { resolveDraftItems } from './resolveDraftItems';
import type { Product, ReceivingItem } from '../../domain/entities';

function product(over: Partial<Product> = {}): Product {
  return {
    id: 'p1', sku: 'BANGUS-1KG', name: 'Bangus 1kg', category: 'Fish', unit: 'kg',
    cost: 180, price: 220, quantity: 5, reorderLevel: 2, costCode: 'AB-CD',
    barcode: null, supplierId: null, supplierName: null, baseSku: null, variationNumber: null,
    isActive: true, imageUrl: null, notes: null, searchKeywords: [], createdAt: new Date(),
    updatedAt: null, createdBy: 'u1', updatedBy: 'u1', createdByName: 'Czar', updatedByName: 'Czar', ...over,
  };
}

function draftItem(over: Partial<ReceivingItem> = {}): ReceivingItem {
  return {
    id: 'i1', productId: 'p1', sku: 'BANGUS-1KG', name: 'Bangus 1kg', quantity: 10,
    unit: 'kg', unitCost: 180, costCode: 'AB-CD', isNewVariation: false, newProductId: null,
    notes: null, ...over,
  };
}

describe('resolveDraftItems', () => {
  it('existing product, same cost → match', () => {
    const out = resolveDraftItems([draftItem({ unitCost: 180 })], [product({ cost: 180 })]);
    expect(out).toEqual([{ ref: 0, kind: 'match', product: expect.objectContaining({ id: 'p1' }), quantity: 10 }]);
  });

  it('existing product, different cost (> tolerance) → mismatch', () => {
    const out = resolveDraftItems([draftItem({ unitCost: 200 })], [product({ cost: 180 })]);
    expect(out[0]).toMatchObject({ kind: 'mismatch', quantity: 10, cost: 200 });
  });

  it('pendingNewProduct → new', () => {
    const out = resolveDraftItems(
      [draftItem({
        productId: '', sku: 'GENERATE', name: 'Squid', unitCost: 90,
        pendingNewProduct: { category: 'Fish', price: 130, reorderLevel: 1, autoGenerateSku: true },
      })],
      [],
    );
    expect(out[0]).toMatchObject({ kind: 'new', name: 'Squid', cost: 90, price: 130, reorderLevel: 1, autoGenerateSku: true });
  });

  it('existing product missing from inventory → skipped', () => {
    const out = resolveDraftItems([draftItem({ productId: 'gone' })], []);
    expect(out).toEqual([]);
  });
});
