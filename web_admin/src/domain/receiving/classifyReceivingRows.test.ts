import { describe, expect, it } from 'vitest';
import type { Product } from '../entities';
import type { ParsedReceivingRow } from './parseReceivingRows';
import { classifyReceivingRows, resolveDuplicateName } from './classifyReceivingRows';

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
    variationNumber: null, barcodes: [], sellingOptions: [], category: 'Engine', imageUrl: null, notes: null,
    ...over,
  };
}

describe('classifyReceivingRows', () => {
  it('match when SKU found and cost within 0.01', () => {
    const [c] = classifyReceivingRows([row({ cost: 60.005 })], [product()], new Map());
    expect(c.status).toBe('match');
    expect(c.existing?.id).toBe('p1');
  });

  it('mismatch when SKU found but cost differs', () => {
    const [c] = classifyReceivingRows([row({ cost: 75 })], [product()], new Map());
    expect(c.status).toBe('mismatch');
    expect(c.existing?.id).toBe('p1');
  });

  it('new when SKU not found', () => {
    const [c] = classifyReceivingRows([row({ sku: 'NOPE' })], [product()], new Map());
    expect(c.status).toBe('new');
    expect(c.existing).toBeNull();
  });

  it('new when GENERATE, even if the literal collides', () => {
    const [c] = classifyReceivingRows(
      [row({ sku: 'GENERATE', autoGenerateSku: true })],
      [product({ sku: 'GENERATE', name: 'Unrelated Part' })],
      new Map([['Engine', '0003']]),
    );
    expect(c.status).toBe('new');
  });

  it('error rows stay error', () => {
    const [c] = classifyReceivingRows([row({ errors: ['name is required.'] })], [product()], new Map());
    expect(c.status).toBe('error');
  });
});

describe('classifyReceivingRows — GENERATE rows and category codes', () => {
  const codes = new Map([['Brakes', '0007']]);

  it('a GENERATE row with a coded category stays new', () => {
    const [r] = classifyReceivingRows(
      [row({ sku: 'GENERATE', autoGenerateSku: true, category: 'Brakes' })],
      [],
      codes,
    );
    expect(r.status).toBe('new');
  });

  it('a GENERATE row with an uncoded category is rejected, not name-generated', () => {
    const [r] = classifyReceivingRows(
      [row({ sku: 'GENERATE', autoGenerateSku: true, category: 'Engine' })],
      [],
      codes,
    );
    expect(r.status).toBe('error');
    expect(r.row.errors.join(' ')).toMatch(/no code/i);
  });

  it('a GENERATE row with no category at all is rejected', () => {
    const [r] = classifyReceivingRows(
      [row({ sku: 'GENERATE', autoGenerateSku: true, category: null })],
      [],
      codes,
    );
    expect(r.status).toBe('error');
  });

  it('an explicit-SKU row never needs a category code', () => {
    const [r] = classifyReceivingRows(
      [row({ sku: 'MANUAL-1', autoGenerateSku: false, category: 'Engine' })],
      [],
      codes,
    );
    expect(r.status).toBe('new');
  });
});

describe('duplicate-name rows', () => {
  it('flags a GENERATE row whose name+category already exists', () => {
    const existing = product({ name: 'BELT BANDO SKYDRIVE', category: 'CVT', sku: '00020152' });
    const [r] = classifyReceivingRows(
      [row({ autoGenerateSku: true, name: 'BANDO SKYDRIVE BELT', category: 'CVT' })],
      [existing],
      new Map([['CVT', '0002']]),
    );
    expect(r.status).toBe('duplicate-name');
    expect(r.existing?.sku).toBe('00020152');
  });

  it('leaves a genuinely new GENERATE row as new', () => {
    const [r] = classifyReceivingRows(
      [row({ autoGenerateSku: true, name: 'BRAND NEW PART', category: 'CVT' })],
      [product({ name: 'BELT BANDO', category: 'CVT' })],
      new Map([['CVT', '0002']]),
    );
    expect(r.status).toBe('new');
  });

  it('does not flag across categories', () => {
    const [r] = classifyReceivingRows(
      [row({ autoGenerateSku: true, name: 'GASKET', category: 'ENGINE' })],
      [product({ name: 'GASKET', category: 'BRAKES' })],
      new Map([['ENGINE', '0017']]),
    );
    expect(r.status).toBe('new');
  });

  it('a typed-SKU row is unaffected — SKU matching still wins', () => {
    const existing = product({ name: 'BELT BANDO', category: 'CVT', sku: '00020152', cost: 120 });
    const [r] = classifyReceivingRows(
      [row({ autoGenerateSku: false, sku: '00020152', name: 'BELT BANDO', category: 'CVT', cost: 120 })],
      [existing],
      new Map(),
    );
    expect(r.status).toBe('match');
  });
});

describe('resolveDuplicateName', () => {
  it('resolves "variation" to match when the cost is the same as the existing product', () => {
    const existing = product({ sku: '00020152', cost: 60 });
    const [r] = classifyReceivingRows(
      [row({ autoGenerateSku: true, name: 'Spark Plug', category: 'Engine', cost: 60 })],
      [existing],
      new Map([['Engine', '0003']]),
    );
    expect(r.status).toBe('duplicate-name');
    const resolved = resolveDuplicateName(r, 'variation');
    expect(resolved.status).toBe('match');
    expect(resolved.existing?.sku).toBe('00020152');
  });

  it('resolves "variation" to mismatch when the cost differs from the existing product', () => {
    const existing = product({ sku: '00020152', cost: 60 });
    const [r] = classifyReceivingRows(
      [row({ autoGenerateSku: true, name: 'Spark Plug', category: 'Engine', cost: 75 })],
      [existing],
      new Map([['Engine', '0003']]),
    );
    const resolved = resolveDuplicateName(r, 'variation');
    expect(resolved.status).toBe('mismatch');
    expect(resolved.existing?.sku).toBe('00020152');
  });

  it('resolves "new" by clearing the name match', () => {
    const existing = product({ sku: '00020152', cost: 60 });
    const [r] = classifyReceivingRows(
      [row({ autoGenerateSku: true, name: 'Spark Plug', category: 'Engine', cost: 60 })],
      [existing],
      new Map([['Engine', '0003']]),
    );
    const resolved = resolveDuplicateName(r, 'new');
    expect(resolved.status).toBe('new');
    expect(resolved.existing).toBeNull();
  });

  it('is a no-op on a row that is not duplicate-name', () => {
    const [r] = classifyReceivingRows([row({ sku: 'NOPE' })], [product()], new Map());
    expect(resolveDuplicateName(r, 'variation')).toBe(r);
  });
});

