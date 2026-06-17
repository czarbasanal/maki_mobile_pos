import { describe, expect, it } from 'vitest';
import { classifiedToReceivable } from './receivableItem';
import type { ClassifiedReceivingRow } from './classifyReceivingRows';
import type { Product } from '../entities';

function product(over: Partial<Product> = {}): Product {
  return {
    id: 'p1', sku: 'BANGUS-1KG', name: 'Bangus 1kg', category: 'Fish', unit: 'kg',
    cost: 180, price: 220, quantity: 5, reorderLevel: 2, costCode: 'AB-CD',
    barcode: null, supplierId: null, supplierName: null, baseSku: null,
    variationNumber: null, isActive: true, imageUrl: null, notes: null,
    searchKeywords: [], createdAt: new Date(), updatedAt: null,
    createdBy: 'u1', updatedBy: 'u1', createdByName: 'Czar', updatedByName: 'Czar', ...over,
  };
}

function row(
  status: ClassifiedReceivingRow['status'],
  over: Partial<ClassifiedReceivingRow['row']> = {},
  existing: Product | null = null,
): ClassifiedReceivingRow {
  return {
    status,
    existing,
    row: {
      rowNumber: 1, sku: 'BANGUS-1KG', name: 'Bangus 1kg', category: 'Fish', unit: 'kg',
      cost: 180, price: 220, quantity: 10, reorderLevel: 2, autoGenerateSku: false,
      errors: [], warnings: [], ...over,
    },
  };
}

describe('classifiedToReceivable', () => {
  it('maps a match to {kind:match, product, quantity}', () => {
    const p = product();
    expect(classifiedToReceivable(row('match', { quantity: 10 }, p))).toEqual({
      ref: 1, kind: 'match', product: p, quantity: 10,
    });
  });

  it('maps a mismatch to {kind:mismatch, product, quantity, cost}', () => {
    const p = product();
    expect(classifiedToReceivable(row('mismatch', { quantity: 4, cost: 200 }, p))).toEqual({
      ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200,
    });
  });

  it('maps a new row to {kind:new, ...row fields}', () => {
    expect(
      classifiedToReceivable(
        row('new', {
          sku: 'GENERATE', autoGenerateSku: true, name: 'Squid', category: 'Fish',
          unit: 'kg', cost: 90, price: 130, quantity: 3, reorderLevel: 1, rowNumber: 7,
        }),
      ),
    ).toEqual({
      ref: 7, kind: 'new', sku: 'GENERATE', autoGenerateSku: true, name: 'Squid',
      category: 'Fish', unit: 'kg', cost: 90, price: 130, quantity: 3, reorderLevel: 1,
    });
  });

  it('returns null for error rows', () => {
    expect(classifiedToReceivable(row('error'))).toBeNull();
  });
});
