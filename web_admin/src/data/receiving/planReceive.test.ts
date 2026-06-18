import { describe, expect, it } from 'vitest';
import { planReceive, type ReceiveContext } from './planReceive';
import type { Product } from '../../domain/entities';
import { defaultCostCode } from '../../domain/entities/CostCode';

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

const ctx = (over: Partial<ReceiveContext> = {}): ReceiveContext => ({
  cipher: defaultCostCode, actor: { id: 'u1', name: 'Czar' }, supplier: null, knownSkus: [], ...over,
});

/** Deterministic id generator for assertions. */
function counter() {
  let n = 0;
  return () => `prod-${++n}`;
}

describe('planReceive', () => {
  it('match → an increment + a line item, no create', () => {
    const p = product({ id: 'p1', cost: 180 });
    const plan = planReceive([{ ref: 1, kind: 'match', product: p, quantity: 10 }], ctx(), counter());
    expect(plan.increments.get('p1')).toBe(10);
    expect(plan.creates).toHaveLength(0);
    expect(plan.items[0]).toMatchObject({ productId: 'p1', quantity: 10, unitCost: 180, isNewVariation: false });
    expect(plan.received).toBe(1);
  });

  it('new → a planned create + line item; auto-generates SKU when asked', () => {
    const plan = planReceive(
      [{ ref: 1, kind: 'new', sku: 'GENERATE', autoGenerateSku: true, name: 'Squid', category: 'Fish', unit: 'kg', cost: 90, price: 130, quantity: 3, reorderLevel: 1 }],
      ctx(), counter(),
    );
    expect(plan.creates).toHaveLength(1);
    expect(plan.newProducts).toBe(1);
    expect(plan.creates[0].productId).toBe('prod-1');
    expect(plan.creates[0].input.sku).not.toBe('GENERATE');
    expect(plan.creates[0].input.quantity).toBe(3);
    expect(plan.creates[0].priceHistory.reason).toBe('Initial price');
    expect(plan.items[0]).toMatchObject({ productId: 'prod-1', name: 'Squid', isNewVariation: false, newProductId: null });
  });

  it('mismatch → a <base>-1 variation create, price-history "receiving", variation line item', () => {
    const p = product({ id: 'p1', sku: 'SP', baseSku: null, cost: 180 });
    const plan = planReceive([{ ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200 }], ctx({ knownSkus: ['SP'] }), counter());
    expect(plan.variations).toBe(1);
    expect(plan.creates[0].input.sku).toBe('SP-1');
    expect(plan.creates[0].priceHistory).toMatchObject({ cost: 200, reason: 'receiving' });
    expect(plan.items[0]).toMatchObject({ productId: 'p1', sku: 'SP-1', unitCost: 200, isNewVariation: true, newProductId: 'prod-1' });
  });

  it('two mismatches of the same base allocate SP-1 then SP-2 (no self-collision)', () => {
    const p = product({ id: 'p1', sku: 'SP', cost: 180 });
    const plan = planReceive(
      [
        { ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200 },
        { ref: 2, kind: 'mismatch', product: p, quantity: 2, cost: 210 },
      ],
      ctx({ knownSkus: ['SP'] }), counter(),
    );
    expect(plan.creates.map((c) => c.input.sku)).toEqual(['SP-1', 'SP-2']);
  });
});
