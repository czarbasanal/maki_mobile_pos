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
    barcodes: [], sellingOptions: [], supplierId: null, supplierName: null, baseSku: null,
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
    expect(repo.create).not.toHaveBeenCalled();
  });

  it('new → creates a product and emits an item; auto rows go through the code', async () => {
    const items: ReceivableItem[] = [{
      ref: 1, kind: 'new', sku: '00090001', autoGenerateSku: true, name: 'Squid',
      category: 'Fish', unit: 'kg', cost: 90, price: 130, quantity: 3, reorderLevel: 1,
      autoSkuCategoryCode: '0009', barcodes: [], notes: null, sellingOptions: [],
    }];
    const repo = fakeRepo();
    const out = await applyReceivedItems(items, repo, ctx());
    expect(repo.create).toHaveBeenCalledTimes(1);
    expect(out.newProducts).toBe(1);
    expect(out.items[0]).toMatchObject({ name: 'Squid', quantity: 3, unitCost: 90, isNewVariation: false, newProductId: null });
    expect(out.items[0].sku).toBe('00090001');
  });

  it('mismatch → the variation inherits the base product’s image and selling options', async () => {
    // Parity with mobile's createVariation and the New Product form: a cost
    // variation is the same physical part, so it keeps the photo and pack sizes.
    const p = product({
      id: 'p1', sku: 'SP', cost: 180,
      imageUrl: 'https://example.test/sp.jpg',
      sellingOptions: [{ id: 'o1', label: 'Half set', pieces: 2, price: 130 }],
    });
    const items: ReceivableItem[] = [{ ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200, price: null }];
    const repo = fakeRepo();
    await applyReceivedItems(items, repo, ctx({ knownSkus: ['SP'] }));
    const input = (repo.create as unknown as { mock: { calls: [{ imageUrl: string | null; sellingOptions: unknown }][] } }).mock.calls[0][0];
    expect(input.imageUrl).toBe('https://example.test/sp.jpg');
    expect(input.sellingOptions).toEqual([{ id: 'o1', label: 'Half set', pieces: 2, price: 130 }]);
  });

  it('new → a genuinely new product still starts with no image or selling options', async () => {
    const items: ReceivableItem[] = [{
      ref: 1, kind: 'new', sku: 'SQ', autoGenerateSku: false, name: 'Squid',
      category: 'Fish', unit: 'kg', cost: 90, price: 130, quantity: 3, reorderLevel: 1,
      autoSkuCategoryCode: null, barcodes: [], notes: null, sellingOptions: [],
    }];
    const repo = fakeRepo();
    await applyReceivedItems(items, repo, ctx());
    const input = (repo.create as unknown as { mock: { calls: [{ imageUrl: string | null; sellingOptions: unknown }][] } }).mock.calls[0][0];
    expect(input.imageUrl).toBeNull();
    expect(input.sellingOptions).toEqual([]);
  });

  it('mismatch → creates a <base>-N variation, records a price change, emits a variation item', async () => {
    const p = product({ id: 'p1', sku: 'SP', baseSku: null, cost: 180 });
    const items: ReceivableItem[] = [{ ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200, price: null }];
    const repo = fakeRepo();
    const out = await applyReceivedItems(items, repo, ctx({ knownSkus: ['SP'] }));
    expect(repo.create).toHaveBeenCalledTimes(1);
    expect(repo.recordPriceChange).toHaveBeenCalledTimes(1);
    expect(out.variations).toBe(1);
    expect(out.items[0]).toMatchObject({ productId: 'p1', sku: 'SP-1', unitCost: 200, isNewVariation: true });
    expect(out.items[0].newProductId).toMatch(/.+/);
  });

  it(
    'mismatch → a product WITH selling options still records exactly one base price ' +
      'change, never one per option (Task 16b: the receiving path is deliberately not ' +
      'option-aware — option cost is reconstructible as pieces x unitCost)',
    async () => {
      const p = product({
        id: 'p1', sku: 'SP', baseSku: null, cost: 180,
        sellingOptions: [
          { id: 'o1', label: 'By 6', pieces: 6, price: 600 },
          { id: 'o2', label: 'By 3', pieces: 3, price: 330 },
        ],
      });
      const items: ReceivableItem[] = [{ ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200, price: null }];
      const repo = fakeRepo();
      await applyReceivedItems(items, repo, ctx({ knownSkus: ['SP'] }));

      expect(repo.recordPriceChange).toHaveBeenCalledTimes(1);
      const [, entry] = vi.mocked(repo.recordPriceChange).mock.calls[0];
      expect(entry).toMatchObject({ price: p.price, cost: 200, reason: 'receiving' });
      expect(entry.optionId).toBeUndefined();
      expect(entry.optionLabel).toBeUndefined();
      expect(entry.optionPieces).toBeUndefined();
    },
  );

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
      [{ ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200, price: null }],
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
      [{ ref: 9, kind: 'new', sku: 'X', autoGenerateSku: false, name: 'X', category: null, unit: 'pcs', cost: 1, price: 2, quantity: 1, reorderLevel: 0, autoSkuCategoryCode: null, barcodes: [], notes: null, sellingOptions: [], }],
      repo, ctx(),
    );
    expect(out.items).toHaveLength(0);
    expect(out.failed).toEqual([{ ref: 9, message: 'boom' }]);
  });
});

describe('applyReceivedItems — category-driven auto-SKU', () => {
  it('hands the category code to create() so its transaction allocates the SKU', async () => {
    const items: ReceivableItem[] = [{
      ref: 1, kind: 'new', sku: '00070001', autoGenerateSku: true, name: 'Brake shoe',
      category: 'Brakes', unit: 'set', cost: 90, price: 130, quantity: 2, reorderLevel: 1,
      autoSkuCategoryCode: '0007', barcodes: [], notes: null, sellingOptions: [],
    }];
    const repo = fakeRepo();
    const out = await applyReceivedItems(items, repo, ctx());
    expect(out.failed).toHaveLength(0);
    const call = (repo.create as ReturnType<typeof vi.fn>).mock.calls[0];
    expect(call[0].sku).toBe('00070001');
    expect(call[2]).toBe('0007');
  });

  it('an auto row with NO code fails its row instead of minting a name-based SKU', async () => {
    // Classification rejects these before they get here; this is the
    // defensive backstop, and the retired generator must never run.
    const items: ReceivableItem[] = [{
      ref: 9, kind: 'new', sku: 'GENERATE', autoGenerateSku: true, name: 'Squid',
      category: null, unit: 'kg', cost: 90, price: 130, quantity: 3, reorderLevel: 1,
      autoSkuCategoryCode: null, barcodes: [], notes: null, sellingOptions: [],
    }];
    const repo = fakeRepo();
    const out = await applyReceivedItems(items, repo, ctx());
    expect(out.failed).toHaveLength(1);
    expect(out.failed[0].message).toMatch(/no code|category/i);
    expect(repo.create).not.toHaveBeenCalled();
  });
});


describe('applyReceivedItems — supplier mapping + variation price (bulk path)', () => {
  const supplier = { id: 's1', name: 'Boss Atan Argao' };

  it('a variation takes the receiving’s supplier over the base’s', async () => {
    const p = product({ id: 'p1', sku: 'SP', cost: 180, supplierId: 's9', supplierName: 'Old Supplier' });
    const repo = fakeRepo();
    await applyReceivedItems(
      [{ ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200, price: null }],
      repo, ctx({ supplier, knownSkus: ['SP'] }),
    );
    expect(repo.create).toHaveBeenCalledWith(
      expect.objectContaining({ supplierId: 's1', supplierName: 'Boss Atan Argao' }),
      'u1',
    );
  });

  it('the CSV row’s price becomes the variation’s price + history entry', async () => {
    const p = product({ id: 'p1', sku: 'SP', cost: 180, price: 220 });
    const repo = fakeRepo();
    const out = await applyReceivedItems(
      [{ ref: 1, kind: 'mismatch', product: p, quantity: 4, cost: 200, price: 260 }],
      repo, ctx({ knownSkus: ['SP'] }),
    );
    expect(repo.create).toHaveBeenCalledWith(expect.objectContaining({ price: 260 }), 'u1');
    expect(repo.recordPriceChange).toHaveBeenCalledWith('new-1', expect.objectContaining({ price: 260 }));
    expect(out.items[0].unitPrice).toBe(260);
  });

  it('match fills the supplier only when the product has none', async () => {
    const empty = product({ id: 'p1', supplierId: null, supplierName: null });
    const kept = product({ id: 'p2', supplierId: 's9', supplierName: 'Old Supplier' });
    const out = await applyReceivedItems(
      [
        { ref: 1, kind: 'match', product: empty, quantity: 10 },
        { ref: 2, kind: 'match', product: kept, quantity: 3 },
      ],
      fakeRepo(), ctx({ supplier }),
    );
    expect(out.supplierFills.get('p1')).toEqual({ supplierId: 's1', supplierName: 'Boss Atan Argao' });
    expect(out.supplierFills.has('p2')).toBe(false);
  });
});
