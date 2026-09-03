// hardDelete: the doc, its price_history subdocs, and the claims it holds —
// and ONLY the claims it holds (a renamed SKU's key can belong to another
// product). Mirrors scripts/purge-archived-products.mjs semantics.
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { Firestore } from 'firebase/firestore';

const state = vi.hoisted(() => ({
  docs: {} as Record<string, Record<string, unknown> | undefined>,
  subdocs: [] as string[], // price_history paths
  deletes: [] as string[],
  committed: false,
}));

vi.mock('firebase/firestore', () => {
  const ref = (path: string) => ({
    path,
    id: path.split('/').pop(),
    withConverter: () => ref(path),
  });
  return {
    doc: (_db: unknown, ...segs: string[]) => ref(segs.join('/')),
    collection: (_db: unknown, ...segs: string[]) => ref(segs.join('/')),
    getDoc: async (r: { path: string }) => ({
      exists: () => state.docs[r.path] !== undefined,
      data: () => state.docs[r.path],
    }),
    getDocs: async (r: { path: string }) => ({
      forEach: (cb: (d: { ref: { path: string } }) => void) => {
        state.subdocs
          .filter((p) => p.startsWith(`${r.path}/`))
          .forEach((p) => cb({ ref: ref(p) }));
      },
    }),
    writeBatch: () => ({
      delete: (r: { path: string }) => state.deletes.push(r.path),
      commit: async () => {
        state.committed = true;
      },
    }),
    onSnapshot: vi.fn(),
    query: vi.fn(),
    where: vi.fn(),
    orderBy: vi.fn(),
    limit: vi.fn(),
    collectionGroup: vi.fn(),
    addDoc: vi.fn(),
    increment: vi.fn(),
    runTransaction: vi.fn(),
    serverTimestamp: () => 'ts',
    updateDoc: vi.fn(),
    getDoc_: vi.fn(),
    Timestamp: class {},
  };
});

vi.mock('@/data/converters/productConverter', () => ({
  productConverter: { toFirestore: (d: unknown) => d, fromFirestore: (s: unknown) => s },
}));

import { FirestoreProductRepository } from './FirestoreProductRepository';

const repo = () => new FirestoreProductRepository({} as unknown as Firestore);

beforeEach(() => {
  state.docs = {};
  state.subdocs = [];
  state.deletes = [];
  state.committed = false;
});

describe('hardDelete', () => {
  it('deletes the doc, price_history, and the claims this product holds', async () => {
    state.docs['products/p1'] = { sku: '00270002', barcodes: ['4801234'] };
    state.docs['product_skus/00270002'] = { productId: 'p1' };
    state.docs['product_barcodes/4801234'] = { productId: 'p1' };
    state.subdocs = ['products/p1/price_history/h1', 'products/p1/price_history/h2'];

    await repo().hardDelete('p1');

    expect(state.deletes).toEqual([
      'products/p1/price_history/h1',
      'products/p1/price_history/h2',
      'product_skus/00270002',
      'product_barcodes/4801234',
      'products/p1',
    ]);
    expect(state.committed).toBe(true);
  });

  it("leaves claims held by another product and skips missing ones", async () => {
    state.docs['products/p1'] = { sku: '00270002', barcodes: ['4801234'] };
    state.docs['product_skus/00270002'] = { productId: 'SOMEONE-ELSE' };
    // barcode claim missing entirely
    await repo().hardDelete('p1');
    expect(state.deletes).toEqual(['products/p1']);
  });

  it('is a no-op when the product is already gone', async () => {
    await repo().hardDelete('p1');
    expect(state.deletes).toEqual([]);
    expect(state.committed).toBe(false);
  });
});
