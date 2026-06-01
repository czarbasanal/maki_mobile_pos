import { describe, expect, it } from 'vitest';
import type { Product } from '../entities';
import type { ParsedReceivingRow } from './parseReceivingRows';
import { classifyReceivingRows } from './classifyReceivingRows';

function row(over: Partial<ParsedReceivingRow> = {}): ParsedReceivingRow {
  return {
    rowNumber: 2, sku: 'SP-1', name: 'Spark Plug', category: 'Engine', unit: 'pcs',
    cost: 60, price: 100, quantity: 5, reorderLevel: 0, autoGenerateSku: false,
    errors: [], warnings: [], ...over,
  };
}
function product(over: Partial<Product> = {}): Product {
  return {
    id: 'p1', sku: 'SP-1', name: 'Spark Plug', costCode: 'ZS', cost: 60, price: 100,
    quantity: 3, reorderLevel: 0, unit: 'pcs', supplierId: null, supplierName: null,
    isActive: true, createdAt: new Date(), updatedAt: null, createdBy: null, updatedBy: null,
    createdByName: null, updatedByName: null, searchKeywords: [], baseSku: null,
    variationNumber: null, barcode: null, category: 'Engine', imageUrl: null, notes: null,
    ...over,
  };
}

describe('classifyReceivingRows', () => {
  it('match when SKU found and cost within 0.01', () => {
    const [c] = classifyReceivingRows([row({ cost: 60.005 })], [product()]);
    expect(c.status).toBe('match');
    expect(c.existing?.id).toBe('p1');
  });

  it('mismatch when SKU found but cost differs', () => {
    const [c] = classifyReceivingRows([row({ cost: 75 })], [product()]);
    expect(c.status).toBe('mismatch');
    expect(c.existing?.id).toBe('p1');
  });

  it('new when SKU not found', () => {
    const [c] = classifyReceivingRows([row({ sku: 'NOPE' })], [product()]);
    expect(c.status).toBe('new');
    expect(c.existing).toBeNull();
  });

  it('new when GENERATE, even if the literal collides', () => {
    const [c] = classifyReceivingRows([row({ sku: 'GENERATE', autoGenerateSku: true })], [product({ sku: 'GENERATE' })]);
    expect(c.status).toBe('new');
  });

  it('error rows stay error', () => {
    const [c] = classifyReceivingRows([row({ errors: ['name is required.'] })], [product()]);
    expect(c.status).toBe('error');
  });
});
