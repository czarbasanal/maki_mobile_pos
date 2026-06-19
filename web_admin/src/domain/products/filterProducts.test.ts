import { describe, expect, it } from 'vitest';
import { filterProducts, type ProductFilter } from './filterProducts';
import { StockStatus, type Product } from '../entities/Product';

function p(over: Partial<Product>): Product {
  return {
    id: 'id', sku: 'SKU', name: 'Name', costCode: '', cost: 0, price: 0,
    quantity: 0, reorderLevel: 0, unit: 'pcs', supplierId: null, supplierName: null,
    isActive: true, createdAt: new Date(0), updatedAt: null, createdBy: null,
    updatedBy: null, createdByName: null, updatedByName: null, searchKeywords: [],
    baseSku: null, variationNumber: null, barcodes: [], category: null,
    imageUrl: null, notes: null, ...over,
  };
}

const ALL: ProductFilter = { search: '', stock: 'all', category: 'all' };

const products: Product[] = [
  p({ id: 'a', name: 'Coca Cola', sku: 'COKE-1', quantity: 50, reorderLevel: 10, category: 'Drinks' }), // inStock
  p({ id: 'b', name: 'Pepsi', sku: 'PEP-1', quantity: 5, reorderLevel: 10, category: 'Drinks' }),        // lowStock
  p({ id: 'c', name: 'Chips', sku: 'CHIP-1', quantity: 0, reorderLevel: 5, category: 'Snacks' }),        // outOfStock
];

describe('filterProducts', () => {
  it('returns all with the empty filter', () => {
    expect(filterProducts(products, ALL).map((x) => x.id)).toEqual(['a', 'b', 'c']);
  });
  it('searches name and sku (case-insensitive)', () => {
    expect(filterProducts(products, { ...ALL, search: 'cola' }).map((x) => x.id)).toEqual(['a']);
    expect(filterProducts(products, { ...ALL, search: 'pep-1' }).map((x) => x.id)).toEqual(['b']);
  });
  it('filters by stock status', () => {
    expect(filterProducts(products, { ...ALL, stock: StockStatus.inStock }).map((x) => x.id)).toEqual(['a']);
    expect(filterProducts(products, { ...ALL, stock: StockStatus.lowStock }).map((x) => x.id)).toEqual(['b']);
    expect(filterProducts(products, { ...ALL, stock: StockStatus.outOfStock }).map((x) => x.id)).toEqual(['c']);
  });
  it('filters by category', () => {
    expect(filterProducts(products, { ...ALL, category: 'Snacks' }).map((x) => x.id)).toEqual(['c']);
  });
  it('ANDs the axes together', () => {
    expect(
      filterProducts(products, { ...ALL, search: 'p', stock: StockStatus.lowStock, category: 'Drinks' }).map((x) => x.id),
    ).toEqual(['b']);
  });
});
