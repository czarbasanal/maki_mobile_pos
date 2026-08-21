// Cost-variation rules for the New Product form: when a typed SKU collides
// with an existing product at a DIFFERENT cost, we spawn `<base>-N` instead of
// rejecting the save. Mirrors mobile's ProductRepositoryImpl.createVariation
// (lib/data/repositories/product_repository_impl.dart) — the variation copies
// the existing product and starts at zero stock with no barcodes.
import { describe, expect, it } from 'vitest';
import type { Product } from '../entities/Product';
import { buildVariationInput, costsDiffer, nextVariationNumberFrom } from './costVariation';

function product(over: Partial<Product> = {}): Product {
  return {
    id: 'p1',
    sku: 'ABC123',
    name: 'Brake shoe (Yamaha)',
    costCode: 'NBF',
    cost: 170,
    price: 250,
    quantity: 8,
    reorderLevel: 3,
    unit: 'set',
    supplierId: 's1',
    supplierName: 'Supplier One',
    isActive: true,
    createdAt: new Date('2026-01-01'),
    updatedAt: null,
    createdBy: 'someone-else',
    updatedBy: 'someone-else',
    createdByName: 'Someone Else',
    updatedByName: 'Someone Else',
    searchKeywords: ['abc123'],
    baseSku: null,
    variationNumber: null,
    barcodes: ['4800123456789'],
    sellingOptions: [{ id: 'o1', label: 'Half set', pieces: 2, price: 130 }],
    category: 'Brakes',
    imageUrl: 'https://example.test/img.png',
    notes: 'handle with care',
    ...over,
  };
}

describe('costsDiffer — the variation trigger', () => {
  it('treats a one-centavo gap as the same cost', () => {
    expect(costsDiffer(170, 170.01)).toBe(false);
  });

  it('treats anything past a centavo as a different cost', () => {
    expect(costsDiffer(170, 170.02)).toBe(true);
  });

  it('is direction-agnostic — a cheaper delivery still varies', () => {
    expect(costsDiffer(185, 170)).toBe(true);
  });
});

describe('nextVariationNumberFrom', () => {
  it('starts at 1 when the base has no variations yet', () => {
    expect(nextVariationNumberFrom([])).toBe(1);
  });

  it('takes the max, not the count — a deleted variation must not collide', () => {
    // -1 and -3 live, -2 was deleted. Counting would return 3 and collide
    // with the existing ABC123-3; maxing returns 4.
    expect(nextVariationNumberFrom([1, 3])).toBe(4);
  });

  it('ignores products carrying no variation number', () => {
    expect(nextVariationNumberFrom([null, undefined, 2])).toBe(3);
  });
});

describe('buildVariationInput', () => {
  const opts = {
    cost: 185,
    costCode: 'XYZ',
    variationNumber: 1,
    actorId: 'user-1',
    actorName: 'User One',
  };

  it('suffixes the base SKU and records the link back to it', () => {
    const input = buildVariationInput(product(), opts);
    expect(input.sku).toBe('ABC123-1');
    expect(input.baseSku).toBe('ABC123');
    expect(input.variationNumber).toBe(1);
  });

  it('roots a variation-of-a-variation at the original base', () => {
    const input = buildVariationInput(
      product({ sku: 'ABC123-1', baseSku: 'ABC123', variationNumber: 1 }),
      { ...opts, variationNumber: 2 },
    );
    expect(input.sku).toBe('ABC123-2');
    expect(input.baseSku).toBe('ABC123');
  });

  it('takes the new cost and cost code', () => {
    const input = buildVariationInput(product(), opts);
    expect(input.cost).toBe(185);
    expect(input.costCode).toBe('XYZ');
  });

  it('starts at zero stock — receiving or a stock edit puts units on it', () => {
    const input = buildVariationInput(product(), opts);
    expect(input.quantity).toBe(0);
  });

  it('claims no barcodes — the manufacturer code stays with the base item', () => {
    const input = buildVariationInput(product(), opts);
    expect(input.barcodes).toEqual([]);
  });

  it('carries the existing product’s descriptive fields', () => {
    const input = buildVariationInput(product(), opts);
    expect(input.name).toBe('Brake shoe (Yamaha)');
    expect(input.price).toBe(250);
    expect(input.unit).toBe('set');
    expect(input.reorderLevel).toBe(3);
    expect(input.category).toBe('Brakes');
    expect(input.supplierId).toBe('s1');
    expect(input.supplierName).toBe('Supplier One');
    expect(input.notes).toBe('handle with care');
    expect(input.sellingOptions).toEqual([
      { id: 'o1', label: 'Half set', pieces: 2, price: 130 },
    ]);
    expect(input.isActive).toBe(true);
  });

  it('is created active even when varying an archived product', () => {
    // Inheriting isActive:false would create a product the inventory list
    // hides by default: the user sees nothing, assumes the save failed, and
    // the SKU is claimed regardless. A new product is always a live one.
    const input = buildVariationInput(product({ isActive: false }), opts);
    expect(input.isActive).toBe(true);
  });

  it('attributes the variation to the actor creating it, not the original author', () => {
    const input = buildVariationInput(product(), opts);
    expect(input.createdBy).toBe('user-1');
    expect(input.createdByName).toBe('User One');
  });
});
