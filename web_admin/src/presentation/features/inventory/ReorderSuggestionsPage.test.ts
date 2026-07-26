// Pinning test for the reorder CSV export's leading-zero-safe SKU display
// (an 8-digit auto-SKU must render as 'XXXX-XXXX' so Excel/Sheets doesn't
// eat the leading zeros — see displaySku).
import { describe, expect, it } from 'vitest';
import type { Product } from '@/domain/entities';
import type { ReorderSuggestion } from '@/domain/reorder/computeReorderSuggestions';
import { reorderCsvRow } from './ReorderSuggestionsPage';

function product(overrides: Partial<Product> = {}): Product {
  return {
    id: 'p1',
    sku: '00070153',
    name: 'Oil Filter',
    costCode: 'NBF',
    cost: 100,
    price: 150,
    quantity: 3,
    reorderLevel: 5,
    unit: 'pcs',
    supplierId: null,
    supplierName: null,
    isActive: true,
    createdAt: new Date(),
    updatedAt: null,
    createdBy: null,
    updatedBy: null,
    createdByName: null,
    updatedByName: null,
    searchKeywords: [],
    baseSku: null,
    variationNumber: null,
    barcodes: [],
    category: null,
    imageUrl: null,
    notes: null,
    ...overrides,
  };
}

function suggestion(overrides: Partial<ReorderSuggestion> = {}): ReorderSuggestion {
  return {
    product: product(),
    supplierName: 'Acme',
    velocityPerDay: 1.5,
    targetStock: 20,
    suggestedQty: 17,
    ...overrides,
  };
}

describe('reorderCsvRow', () => {
  it('formats an 8-digit auto-SKU as XXXX-XXXX', () => {
    const row = reorderCsvRow(suggestion(), 17);
    expect(row[1]).toBe('0007-0153');
  });

  it('leaves a non-auto SKU unchanged', () => {
    const row = reorderCsvRow(suggestion({ product: product({ sku: 'BRAKE-99' }) }), 17);
    expect(row[1]).toBe('BRAKE-99');
  });
});
