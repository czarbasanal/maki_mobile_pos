// Allocation + retry for cost variations. Two writers spawning a variation off
// the same base race for `<base>-N`; the loser must recompute rather than fail,
// which is what mobile's createVariation retry loop does
// (lib/data/repositories/product_repository_impl.dart).
import { describe, expect, it, vi } from 'vitest';
import type { Product } from '@/domain/entities/Product';
import type { ProductCreateInput } from '@/domain/repositories/ProductRepository';
import { DuplicateSkuError } from '../errors';
import { allocateVariation } from './createVariation';

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
    supplierId: null,
    supplierName: null,
    isActive: true,
    createdAt: new Date('2026-01-01'),
    updatedAt: null,
    createdBy: 'someone-else',
    updatedBy: null,
    createdByName: 'Someone Else',
    updatedByName: null,
    searchKeywords: [],
    baseSku: null,
    variationNumber: null,
    barcodes: ['4800123456789'],
    sellingOptions: [],
    category: 'Brakes',
    imageUrl: null,
    notes: null,
    ...over,
  };
}

const opts = { cost: 185, costCode: 'XYZ', price: 250, actorId: 'user-1', actorName: 'User One' };

/** Fake repo whose SKU claims are a Set — `create` rejects an already-claimed
 *  SKU exactly as the real transaction does, so the retry is exercised for
 *  real rather than asserted against a mock's call count. */
function fakeRepo(claimed: string[] = [], liveNumbers: number[] = []) {
  const claims = new Set(claimed);
  const numbers = [...liveNumbers];
  return {
    claims,
    nextNumber: vi.fn(async () => {
      let max = 0;
      for (const n of numbers) if (n > max) max = n;
      return max + 1;
    }),
    create: vi.fn(async (input: ProductCreateInput): Promise<Product> => {
      if (claims.has(input.sku)) {
        // The racing writer's product has now committed, so its number is
        // visible to the next recompute — exactly the situation mobile's
        // retry comment describes.
        numbers.push(input.variationNumber!);
        throw new DuplicateSkuError();
      }
      claims.add(input.sku);
      numbers.push(input.variationNumber!);
      return { ...product(), id: `new-${input.sku}`, ...input } as Product;
    }),
  };
}

describe('allocateVariation', () => {
  it('creates <base>-1 when nothing is claimed yet', async () => {
    const repo = fakeRepo();

    const created = await allocateVariation(product(), opts, repo);

    expect(created.sku).toBe('ABC123-1');
    expect(created.cost).toBe(185);
    expect(repo.create).toHaveBeenCalledTimes(1);
  });

  it('recomputes and retries when a concurrent writer takes the number', async () => {
    // The allocator computes 1, but ABC123-1 was claimed by another writer in
    // the instant before the write lands. The recompute must yield 2.
    const repo = fakeRepo(['ABC123-1']);

    const created = await allocateVariation(product(), opts, repo);

    expect(created.sku).toBe('ABC123-2');
    expect(repo.create).toHaveBeenCalledTimes(2);
  });

  it('advances past a claimed SKU that carries no variation number', async () => {
    // ABC123-1 exists as a SKU claim but has no `variationNumber` — a
    // hand-typed product, or one from the bulk import. nextNumber() reads the
    // structured field, so it keeps answering 1; without a local floor the
    // allocator would retry the same doomed SKU until it gave up, leaving that
    // base permanently unvariable.
    const claims = new Set(['ABC123-1']);
    const repo = {
      nextNumber: vi.fn(async () => 1),
      create: vi.fn(async (input: ProductCreateInput): Promise<Product> => {
        if (claims.has(input.sku)) throw new DuplicateSkuError();
        return { ...product(), ...input } as Product;
      }),
    };

    const created = await allocateVariation(product(), opts, repo);

    expect(created.sku).toBe('ABC123-2');
    expect(repo.create).toHaveBeenCalledTimes(2);
  });

  it('gives up with a clear error only once every candidate is taken', async () => {
    const claims = new Set(['ABC123-1', 'ABC123-2', 'ABC123-3']);
    const repo = {
      nextNumber: vi.fn(async () => 1),
      create: vi.fn(async (input: ProductCreateInput): Promise<Product> => {
        if (claims.has(input.sku)) throw new DuplicateSkuError();
        return product() as Product;
      }),
    };

    await expect(allocateVariation(product(), opts, repo, 3)).rejects.toThrow(
      /ABC123/,
    );
    expect(repo.create).toHaveBeenCalledTimes(3);
  });

  it('does not swallow unrelated failures', async () => {
    const repo = {
      nextNumber: vi.fn(async () => 1),
      create: vi.fn(async (): Promise<Product> => {
        throw new Error('offline');
      }),
    };

    await expect(allocateVariation(product(), opts, repo)).rejects.toThrow('offline');
    expect(repo.create).toHaveBeenCalledTimes(1);
  });

  it('allocates against the root base when varying an existing variation', async () => {
    const repo = fakeRepo([], [1]);

    const created = await allocateVariation(
      product({ sku: 'ABC123-1', baseSku: 'ABC123', variationNumber: 1 }),
      opts,
      repo,
    );

    expect(created.sku).toBe('ABC123-2');
    expect(created.baseSku).toBe('ABC123');
  });
});
