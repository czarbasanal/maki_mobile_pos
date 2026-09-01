import { describe, expect, it } from 'vitest';
import { findByScannedCode, matchesPosQuery } from './posSearch';
import type { Product } from '@/domain/entities';

const product = (o: Partial<Product>): Product =>
  ({
    id: 'p1', sku: '00070153', name: 'Spark Plug', category: 'Engine',
    barcodes: ['4806534240013'], isActive: true, quantity: 5,
    ...o,
  }) as Product;

describe('matchesPosQuery', () => {
  const p = product({});
  it('matches name, category, barcode and sku substrings', () => {
    expect(matchesPosQuery(p, 'spark')).toBe(true);
    expect(matchesPosQuery(p, 'engine')).toBe(true);
    expect(matchesPosQuery(p, '480653')).toBe(true);
    expect(matchesPosQuery(p, '0007')).toBe(true);
  });
  it('matches a variation SKU with its literal dash', () => {
    const variation = product({ id: 'p3', sku: '00070153-2', name: 'Spark Plug (v2)' });
    expect(matchesPosQuery(variation, '00070153-2')).toBe(true);
    expect(matchesPosQuery(variation, '0153-2')).toBe(true);
  });
  it('rejects a blank query and non-matches', () => {
    expect(matchesPosQuery(p, '  ')).toBe(false);
    expect(matchesPosQuery(p, 'muffler')).toBe(false);
  });
});

describe('findByScannedCode', () => {
  const products = [product({}), product({ id: 'p2', sku: 'MLK-A3B7', name: 'Bulb', barcodes: [] })];
  it('resolves by exact barcode first', () => {
    expect(findByScannedCode(products, '4806534240013')?.id).toBe('p1');
  });
  it('falls back to exact SKU — plain and variation shapes', () => {
    expect(findByScannedCode(products, '00070153')?.id).toBe('p1');
    expect(findByScannedCode(products, 'mlk-a3b7')?.id).toBe('p2');
    const withVariation = [...products, product({ id: 'p3', sku: '00070153-2', barcodes: [] })];
    expect(findByScannedCode(withVariation, '00070153-2')?.id).toBe('p3');
  });
  it('null when nothing matches', () => {
    expect(findByScannedCode(products, '999')).toBeNull();
  });
});
