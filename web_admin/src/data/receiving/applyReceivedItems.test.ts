import { describe, expect, it, vi } from 'vitest';
import { applyReceivedItems, type ReceiveContext } from './applyReceivedItems';
import type { ReceivableItem } from '../../domain/receiving/receivableItem';
import type { Product } from '../../domain/entities';
import type { ProductRepository } from '../../domain/repositories/ProductRepository';
import { DuplicateSkuError } from '../errors';
import { defaultCostCode } from '../../domain/entities/CostCode';

function product(over: Partial<Product> = {}): Product {
  return {
    id: 'p1', sku: 'BANGUS-1KG', name: 'Bangus 1kg', category: 'Fish', unit: 'kg',
    cost: 180, price: 220, quantity: 5, reorderLevel: 2, costCode: 'AB-CD',
    barcodes: [], supplierId: null, supplierName: null, baseSku: null,
    variationNumber: null, isActive: true, imageUrl: null, notes: null,
    searchKeywords: [], createdAt: new Date(), updatedAt: null,
    createdBy: 'u1', updatedBy: 'u1', createdByName: 'Czar', updatedByName: 'Czar', ...over,
  };
}

const ctx = (over: Partial<ReceiveContext> = {}): ReceiveContext => ({
  cipher: defaultCostCode, actor: { id: 'u1', name: 'Czar' }, supplier: null, knownSkus: [], ...over,
});

/** Minimal in-memory ProductRepository — only the methods the engine calls. */
function fakeRepo(over: Partial<ProductRepository> = {}): ProductRepository {
  let seq = 0;
  return {
    create: vi.fn(async (input) => ({
      ...input, id: `new-${++seq}`, createdAt: new Date(), updatedAt: null,
      searchKeywords: input.searchKeywords ?? [],
    } as Product)),
    recordPriceChange: vi.fn(async () => {}),
    ...over,
  } as unknown as ProductRepository;
}

describe('applyReceivedItems', () => {
  it('match → accumulates an increment and emits an item at the product cost', async () => {
    const p = product({ id: 'p1', cost: 180 });
    const items: ReceivableItem[] = [{ ref: 1, kind: 'match', product: p, quantity: 10 }];
    const repo = fakeRepo();
    const out = await applyReceivedItems(items, repo, ctx());
    expect(out.increments.get('p1')).toBe(10);
    expect(out.items).toHaveLength(1);
    expect(out.items[0]).toMatchObject({ productId: 'p1', quantity: 10, unitCost: 180, isNewVariation: false });
    expect(out.items[0].id).toMatch(/.+/);
    expect(out.received).toBe(10);
    expect(repo.create).not.toHaveBeenCalled();
  });

  it('new → creates a product and emits an item; auto-generates SKU when asked', async () => {
    const items: ReceivableItem[] = [{
      ref: 1, kind: 'new', sku: 'GENERATE', autoGenerateSku: true, name: 'Squid',
      category: 'Fish', unit: 'kg', cost: 90, price: 130, quantity: 3, reorderLevel: 1,
    }];
    const repo = fakeRepo();
    const out = await applyReceivedItems(items, repo, ctx());
    expect(repo.create).toHaveBeenCalledTimes(1);
    expect(out.newProducts).toBe(1);
    expect(out.items[0]).toMatchObject({ name: 'Squid', quantity: 3, unitCost: 90, isNewVariation: false, newProductId: null });
    expect(out.items[0].sku).not.toBe('GENERATE'); // auto-generated
  });

  it('mismatch → creates a <base>-N variation, records a price change, emits a variation item', async () => {
    const p = product({ id: 'p1', sku: 'SP', baseSku: null, cost: 180 });
    const items: ReceivableItem[] = [{ ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200 }];
    const repo = fakeRepo();
    const out = await applyReceivedItems(items, repo, ctx({ knownSkus: ['SP'] }));
    expect(repo.create).toHaveBeenCalledTimes(1);
    expect(repo.recordPriceChange).toHaveBeenCalledTimes(1);
    expect(out.variations).toBe(1);
    expect(out.items[0]).toMatchObject({ productId: 'p1', sku: 'SP-1', unitCost: 200, isNewVariation: true });
    expect(out.items[0].newProductId).toMatch(/.+/);
  });

  it('mismatch → retries the next variation number on DuplicateSkuError', async () => {
    const p = product({ id: 'p1', sku: 'SP', cost: 180 });
    let calls = 0;
    const repo = fakeRepo({
      create: vi.fn(async (input) => {
        calls += 1;
        if (input.sku === 'SP-1') throw new DuplicateSkuError('SP-1');
        return { ...input, id: 'v1', createdAt: new Date(), updatedAt: null, searchKeywords: [] } as Product;
      }),
      recordPriceChange: vi.fn(async () => {}),
    });
    const out = await applyReceivedItems(
      [{ ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200 }],
      repo, ctx({ knownSkus: ['SP'] }),
    );
    expect(calls).toBe(2);
    expect(out.items[0].sku).toBe('SP-2');
  });

  it('records a failure (does not throw) when a line cannot be processed', async () => {
    const repo = fakeRepo({
      create: vi.fn(async () => { throw new Error('boom'); }),
      recordPriceChange: vi.fn(async () => {}),
    });
    const out = await applyReceivedItems(
      [{ ref: 9, kind: 'new', sku: 'X', autoGenerateSku: false, name: 'X', category: null, unit: 'pcs', cost: 1, price: 2, quantity: 1, reorderLevel: 0 }],
      repo, ctx(),
    );
    expect(out.items).toHaveLength(0);
    expect(out.failed).toEqual([{ ref: 9, message: 'boom' }]);
  });
});
