import { describe, expect, it } from 'vitest';
import { buildBuyingListRows } from './buyingListRows';
import type { Product } from '@/domain/entities';

const product = (o: Partial<Product> = {}): Product =>
  ({
    id: 'p1', sku: '0001', name: 'Part', price: 100, cost: 60, unit: 'pcs',
    quantity: 5, reorderLevel: 0, isActive: true, supplierName: null,
    ...o,
  }) as Product;

describe('buildBuyingListRows', () => {
  it('lists an out-of-stock part even with no sales at all', () => {
    // The engine's blind spot: velocity 0 excluded it, and a part that sold
    // out early has no velocity left to measure — invisible exactly when it
    // matters most.
    const rows = buildBuyingListRows(
      [product({ id: 'p1', quantity: 0, reorderLevel: 4 })],
      new Map(),
      { windowDays: 30, coverDays: 14 },
    );

    expect(rows).toHaveLength(1);
    expect(rows[0].outOfStock).toBe(true);
    expect(rows[0].suggestedQty).toBe(4); // its own reorder level
  });

  it('falls back to 1 when the part has no reorder level set', () => {
    const rows = buildBuyingListRows(
      [product({ quantity: 0, reorderLevel: 0 })],
      new Map(),
      { windowDays: 30, coverDays: 14 },
    );
    expect(rows[0].suggestedQty).toBe(1);
  });

  it('prefers the velocity suggestion when the part has sales history', () => {
    // Out of stock AND selling: cover days win over the hand-set level.
    const rows = buildBuyingListRows(
      [product({ id: 'p1', quantity: 0, reorderLevel: 2 })],
      new Map([['p1', 60]]), // 2/day over 30 days
      { windowDays: 30, coverDays: 14 },
    );
    expect(rows[0].suggestedQty).toBe(28); // ceil(2 * 14) - 0
  });

  it('still suggests a stocked part that will run low', () => {
    const rows = buildBuyingListRows(
      [product({ id: 'p1', quantity: 3 })],
      new Map([['p1', 30]]), // 1/day
      { windowDays: 30, coverDays: 14 },
    );
    expect(rows[0].outOfStock).toBe(false);
    expect(rows[0].suggestedQty).toBe(11); // 14 - 3
  });

  it('leaves out a well-stocked part with no urgency', () => {
    const rows = buildBuyingListRows(
      [product({ id: 'p1', quantity: 100 })],
      new Map([['p1', 30]]),
      { windowDays: 30, coverDays: 14 },
    );
    expect(rows).toHaveLength(0);
  });

  it('never lists an inactive part', () => {
    const rows = buildBuyingListRows(
      [product({ quantity: 0, isActive: false })],
      new Map(),
      { windowDays: 30, coverDays: 14 },
    );
    expect(rows).toHaveLength(0);
  });

  it('puts out-of-stock first, then by supplier, then by quantity', () => {
    const rows = buildBuyingListRows(
      [
        product({ id: 'a', quantity: 3, supplierName: 'Maxxis' }),
        product({ id: 'b', quantity: 0, reorderLevel: 1, supplierName: 'Zebra' }),
      ],
      new Map([['a', 30]]),
      { windowDays: 30, coverDays: 14 },
    );

    expect(rows.map((r) => r.product.id)).toEqual(['b', 'a']);
  });
});
