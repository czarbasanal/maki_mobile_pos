import { describe, expect, it } from 'vitest';
import { classifiedToReceivable } from './receivableItem';
import type { ClassifiedReceivingRow } from './classifyReceivingRows';
import type { Product } from '../entities';

function product(over: Partial<Product> = {}): Product {
  return {
    id: 'p1', sku: 'BANGUS-1KG', name: 'Bangus 1kg', category: 'Fish', unit: 'kg',
    cost: 180, price: 220, quantity: 5, reorderLevel: 2, costCode: 'AB-CD',
    barcodes: [], sellingOptions: [], supplierId: null, supplierName: null, baseSku: null,
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
    expect(classifiedToReceivable(row('match', { quantity: 10 }, p), new Map())).toEqual({
      ref: 1, kind: 'match', product: p, quantity: 10,
    });
  });

  it('maps a mismatch to {kind:mismatch, product, quantity, cost, price} — the CSV price applies to the variation', () => {
    const p = product();
    expect(classifiedToReceivable(row('mismatch', { quantity: 4, cost: 200, price: 260 }, p), new Map())).toEqual({
      ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200, price: 260,
    });
  });

  it('maps a new GENERATE row, resolving its category code and placeholder', () => {
    expect(
      classifiedToReceivable(
        row('new', {
          sku: 'GENERATE', autoGenerateSku: true, name: 'Squid', category: 'Fish',
          unit: 'kg', cost: 90, price: 130, quantity: 3, reorderLevel: 1, rowNumber: 7,
        }),
        new Map([['Fish', '0009']]),
      ),
    ).toEqual({
      // The literal 'GENERATE' never survives: the placeholder engages
      // create()'s claim-scan, which allocates the real sequence.
      ref: 7, kind: 'new', sku: '00090001', autoGenerateSku: true, name: 'Squid',
      category: 'Fish', unit: 'kg', cost: 90, price: 130, quantity: 3, reorderLevel: 1,
      autoSkuCategoryCode: '0009',
      // CSV rows carry none of the modal-only fields.
      barcodes: [], notes: null, sellingOptions: [],
    });
  });

  it('returns null for error rows', () => {
    expect(classifiedToReceivable(row('error'), new Map())).toBeNull();
  });

  it('throws on an unresolved duplicate-name row instead of silently treating it as new', () => {
    // The sole caller always resolves a duplicate-name row (into match,
    // mismatch or new) before calling this — that's a runtime invariant,
    // not a type one. Make a violation loud rather than letting it fall
    // through to kind:'new' unnoticed.
    const p = product();
    expect(() => classifiedToReceivable(row('duplicate-name', {}, p), new Map())).toThrow(
      /duplicate-name|unresolved/i,
    );
  });
});

describe('classifiedToReceivable — auto rows carry the category code', () => {
  it('resolves the code and emits a pattern-matching placeholder SKU', () => {
    const rowIn = {
      row: {
        rowNumber: 3, sku: 'GENERATE', name: 'Brake shoe', category: 'Brakes',
        unit: 'set', cost: 90, price: 130, quantity: 2, reorderLevel: 1,
        autoGenerateSku: true, errors: [], warnings: [],
      },
      status: 'new' as const,
      existing: null,
    };
    const out = classifiedToReceivable(rowIn, new Map([['Brakes', '0007']]));
    expect(out).toMatchObject({
      kind: 'new',
      autoGenerateSku: true,
      autoSkuCategoryCode: '0007',
      // Placeholder only — create()'s transaction allocates the real
      // sequence; it must match the auto pattern for the scan to engage.
      sku: '00070001',
    });
  });
});

