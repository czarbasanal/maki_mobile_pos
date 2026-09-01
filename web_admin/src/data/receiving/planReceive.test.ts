import { describe, expect, it } from 'vitest';
import { planReceive, type ReceiveContext } from './planReceive';
import type { Product } from '../../domain/entities';
import { defaultCostCode } from '../../domain/entities/CostCode';

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

  it('new → a planned create + line item; auto rows keep placeholder + code', () => {
    const plan = planReceive(
      [{ ref: 1, kind: 'new', sku: '00090001', autoGenerateSku: true, name: 'Squid', category: 'Fish', unit: 'kg', cost: 90, price: 130, quantity: 3, reorderLevel: 1, autoSkuCategoryCode: '0009', barcodes: [], notes: null, sellingOptions: [], }],
      ctx(), counter(),
    );
    expect(plan.creates).toHaveLength(1);
    expect(plan.newProducts).toBe(1);
    expect(plan.creates[0].productId).toBe('prod-1');
    // Placeholder survives to the create; executeReceivePlan's claim-scan
    // allocates the real sequence under the code.
    expect(plan.creates[0].input.sku).toBe('00090001');
    expect(plan.creates[0].autoSkuCategoryCode).toBe('0009');
    expect(plan.creates[0].input.quantity).toBe(3);
    expect(plan.creates[0].priceHistory.reason).toBe('Initial price');
    expect(plan.items[0]).toMatchObject({ productId: 'prod-1', name: 'Squid', isNewVariation: false, newProductId: null });
  });

  it('mismatch → a <base>-1 variation create, price-history "receiving", variation line item', () => {
    const p = product({ id: 'p1', sku: 'SP', baseSku: null, cost: 180 });
    const plan = planReceive([{ ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200, price: null }], ctx({ knownSkus: ['SP'] }), counter());
    expect(plan.variations).toBe(1);
    expect(plan.creates[0].input.sku).toBe('SP-1');
    expect(plan.creates[0].priceHistory).toMatchObject({ cost: 200, reason: 'receiving' });
    expect(plan.items[0]).toMatchObject({ productId: 'p1', sku: 'SP-1', unitCost: 200, isNewVariation: true, newProductId: 'prod-1' });
    // With no price entered (null) the variation inherits the base product's
    // price (220) — never the row's cost (200).
    expect(plan.creates[0].input.price).toBe(220);
  });

  it('mismatch → the variation carries the base product’s image and selling options', () => {
    // Full parity with mobile's createVariation and the New Product form: a
    // cost variation is the same physical part, so it keeps the photo and the
    // pack sizes it can be sold in.
    const p = product({
      id: 'p1', sku: 'SP', cost: 180,
      imageUrl: 'https://example.test/sp.jpg',
      sellingOptions: [{ id: 'o1', label: 'Half set', pieces: 2, price: 130 }],
    });
    const plan = planReceive(
      [{ ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200, price: null }],
      ctx({ knownSkus: ['SP'] }), counter(),
    );
    expect(plan.creates[0].input.imageUrl).toBe('https://example.test/sp.jpg');
    expect(plan.creates[0].input.sellingOptions).toEqual([
      { id: 'o1', label: 'Half set', pieces: 2, price: 130 },
    ]);
  });

  it('new → a genuinely new product still starts with no image or selling options', () => {
    // Only a VARIATION inherits; a brand-new product has nothing to inherit from.
    const plan = planReceive(
      [{ ref: 1, kind: 'new', sku: 'SQ', autoGenerateSku: false, name: 'Squid', category: 'Fish', unit: 'kg', cost: 90, price: 130, quantity: 3, reorderLevel: 1, autoSkuCategoryCode: null, barcodes: [], notes: null, sellingOptions: [], }],
      ctx(), counter(),
    );
    expect(plan.creates[0].input.imageUrl).toBeNull();
    expect(plan.creates[0].input.sellingOptions).toEqual([]);
  });

  it('two mismatches of the same base allocate SP-1 then SP-2 (no self-collision)', () => {
    const p = product({ id: 'p1', sku: 'SP', cost: 180 });
    const plan = planReceive(
      [
        { ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200, price: null },
        { ref: 2, kind: 'mismatch', product: p, quantity: 2, cost: 210, price: null },
      ],
      ctx({ knownSkus: ['SP'] }), counter(),
    );
    expect(plan.creates.map((c) => c.input.sku)).toEqual(['SP-1', 'SP-2']);
  });
});

describe('planReceive — new products from the receiving modal', () => {
  const newItem = (over: Record<string, unknown> = {}) => ({
    ref: 1, kind: 'new' as const, sku: '00070005', autoGenerateSku: true,
    name: 'Squid', category: 'Fish', unit: 'kg', cost: 90, price: 130,
    quantity: 3, reorderLevel: 1,
    autoSkuCategoryCode: '0007', barcodes: ['4800111222333'], notes: 'fresh',
    sellingOptions: [{ id: 'o1', label: 'Half kilo', pieces: 2, price: 70 }],
    ...over,
  });

  it('keeps the peeked SKU and carries the category code for the real claim', () => {
    // The preview SKU may be stale by receive time; the executing transaction
    // scans forward from it, so the CODE must survive to the planned create.
    const plan = planReceive([newItem()], ctx(), counter());
    expect(plan.creates[0].input.sku).toBe('00070005');
    expect(plan.creates[0].autoSkuCategoryCode).toBe('0007');
  });

  it('an auto row with no category code throws — the name generator is gone', () => {
    expect(() =>
      planReceive([newItem({ sku: 'GENERATE', autoSkuCategoryCode: null })], ctx(), counter()),
    ).toThrow(/no code|category/i);
  });

  it('passes barcodes, notes and selling options onto the planned product', () => {
    const plan = planReceive([newItem()], ctx(), counter());
    expect(plan.creates[0].input.barcodes).toEqual(['4800111222333']);
    expect(plan.creates[0].input.notes).toBe('fresh');
    expect(plan.creates[0].input.sellingOptions).toEqual([
      { id: 'o1', label: 'Half kilo', pieces: 2, price: 70 },
    ]);
  });
});


describe('planReceive — supplier mapping (fill-when-empty + variation stamping)', () => {
  const supplier = { id: 's1', name: 'Boss Atan Argao' };

  it('a variation takes the RECEIVING’s supplier, not the base’s', () => {
    const p = product({ id: 'p1', sku: 'SP', cost: 180, supplierId: null, supplierName: null });
    const plan = planReceive(
      [{ ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200, price: null }],
      ctx({ supplier, knownSkus: ['SP'] }), counter(),
    );
    expect(plan.creates[0].input.supplierId).toBe('s1');
    expect(plan.creates[0].input.supplierName).toBe('Boss Atan Argao');
  });

  it('a variation falls back to the base’s supplier when the receiving has none', () => {
    const p = product({ id: 'p1', sku: 'SP', cost: 180, supplierId: 's9', supplierName: 'Old Supplier' });
    const plan = planReceive(
      [{ ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200, price: null }],
      ctx({ supplier: null, knownSkus: ['SP'] }), counter(),
    );
    expect(plan.creates[0].input.supplierId).toBe('s9');
    expect(plan.creates[0].input.supplierName).toBe('Old Supplier');
  });

  it('a matched product with NO supplier gets a fill from the receiving', () => {
    const p = product({ id: 'p1', cost: 180, supplierId: null, supplierName: null });
    const plan = planReceive(
      [{ ref: 1, kind: 'match', product: p, quantity: 10 }],
      ctx({ supplier }), counter(),
    );
    expect(plan.supplierFills.get('p1')).toEqual({ supplierId: 's1', supplierName: 'Boss Atan Argao' });
  });

  it('a matched product that already names a supplier is left alone', () => {
    const p = product({ id: 'p1', cost: 180, supplierId: 's9', supplierName: 'Old Supplier' });
    const plan = planReceive(
      [{ ref: 1, kind: 'match', product: p, quantity: 10 }],
      ctx({ supplier }), counter(),
    );
    expect(plan.supplierFills.size).toBe(0);
  });

  it('no supplier on the receiving → no fills at all', () => {
    const p = product({ id: 'p1', cost: 180, supplierId: null, supplierName: null });
    const plan = planReceive(
      [{ ref: 1, kind: 'match', product: p, quantity: 10 }],
      ctx({ supplier: null }), counter(),
    );
    expect(plan.supplierFills.size).toBe(0);
  });
});

describe('planReceive — variation price from the line', () => {
  it('an entered price becomes the variation’s price and its history entry', () => {
    const p = product({ id: 'p1', sku: 'SP', cost: 180, price: 220 });
    const plan = planReceive(
      [{ ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200, price: 260 }],
      ctx({ knownSkus: ['SP'] }), counter(),
    );
    expect(plan.creates[0].input.price).toBe(260);
    expect(plan.creates[0].priceHistory).toMatchObject({ price: 260, cost: 200 });
    expect(plan.items[0].unitPrice).toBe(260);
  });
});
