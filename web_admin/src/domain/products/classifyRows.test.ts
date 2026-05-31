import { describe, expect, it } from 'vitest';
import type { Product, Supplier } from '../entities';
import type { ParsedRow } from './importRows';
import { classifyRows, toCreateInput, toUpdateInput } from './classifyRows';

function parsed(over: Partial<ParsedRow> = {}): ParsedRow {
  return {
    rowNumber: 1,
    name: 'Spark Plug',
    category: 'Engine',
    code: 'NBF',
    cost: 125,
    price: 200,
    quantity: 5,
    reorderLevel: 1,
    unit: 'pcs',
    supplierName: 'Acme',
    errors: [],
    warnings: [],
    ...over,
  };
}

function product(over: Partial<Product> = {}): Product {
  return {
    id: 'p1', sku: 'SP-1', name: 'Spark Plug', costCode: 'NBF', cost: 125, price: 200,
    quantity: 0, reorderLevel: 0, unit: 'pcs', supplierId: null, supplierName: null,
    isActive: true, createdAt: new Date(), updatedAt: null, createdBy: null, updatedBy: null,
    createdByName: null, updatedByName: null, searchKeywords: [], baseSku: null,
    variationNumber: null, barcode: null, category: 'Engine', imageUrl: null, notes: null,
    ...over,
  };
}

const supplier: Supplier = {
  id: 'sup1', name: 'Acme', address: null, contactPerson: null, contactNumber: null,
  alternativeNumber: null, email: null, transactionType: 'cash' as Supplier['transactionType'],
  isActive: true, notes: null, createdAt: new Date(), updatedAt: null, createdBy: null,
  updatedBy: null, productCount: 0, totalInventoryValue: 0,
};

const actor = { id: 'u1', name: 'Admin Jane' };

describe('classifyRows', () => {
  it('marks a name+category match as existing/update and resolves the supplier', () => {
    const [row] = classifyRows([parsed()], [product()], [supplier]);
    expect(row.status).toBe('existing');
    expect(row.matchedProductId).toBe('p1');
    expect(row.defaultAction).toBe('update');
    expect(row.supplierId).toBe('sup1');
    expect(row.supplierMatched).toBe(true);
  });

  it('marks an unmatched row as new/insert', () => {
    const [row] = classifyRows([parsed({ name: 'New Item' })], [product()], [supplier]);
    expect(row.status).toBe('new');
    expect(row.defaultAction).toBe('insert');
  });

  it('marks an error row as error/skip', () => {
    const [row] = classifyRows([parsed({ errors: ['Name is required.'] })], [], []);
    expect(row.status).toBe('error');
    expect(row.defaultAction).toBe('skip');
  });

  it('warns and keeps the name when the supplier is unknown', () => {
    const [row] = classifyRows([parsed({ supplierName: 'Ghost' })], [], []);
    expect(row.supplierId).toBeNull();
    expect(row.supplierMatched).toBe(false);
    expect(row.parsed.warnings.join(' ')).toMatch(/not found/i);
  });

  it('warns when multiple existing products share the name+category', () => {
    const [row] = classifyRows(
      [parsed()],
      [product({ id: 'p1' }), product({ id: 'p2' })],
      [],
    );
    expect(row.matchedProductId).toBe('p1');
    expect(row.parsed.warnings.join(' ')).toMatch(/match/i);
  });
});

describe('toCreateInput / toUpdateInput', () => {
  it('builds a full create input with generated sku + keywords + actor names', () => {
    const [row] = classifyRows([parsed({ name: 'New Item' })], [], [supplier]);
    const input = toCreateInput(row, actor);
    expect(input).toMatchObject({
      name: 'New Item', costCode: 'NBF', cost: 125, price: 200, quantity: 5,
      reorderLevel: 1, unit: 'pcs', supplierId: 'sup1', supplierName: 'Acme',
      isActive: true, createdBy: 'u1', updatedBy: 'u1',
      createdByName: 'Admin Jane', updatedByName: 'Admin Jane',
      baseSku: null, variationNumber: null, barcode: null, category: 'Engine',
    });
    expect(input.sku.length).toBeGreaterThan(0);
    expect(input.searchKeywords).toEqual(expect.arrayContaining(['new', 'item']));
  });

  it('builds an update input with value fields only (no name/category)', () => {
    const [row] = classifyRows([parsed()], [product()], [supplier]);
    const input = toUpdateInput(row, actor);
    expect(input).toMatchObject({
      costCode: 'NBF', cost: 125, price: 200, quantity: 5, reorderLevel: 1,
      unit: 'pcs', supplierId: 'sup1', supplierName: 'Acme',
      updatedBy: 'u1', updatedByName: 'Admin Jane',
    });
    expect('name' in input).toBe(false);
    expect('category' in input).toBe(false);
  });
});
