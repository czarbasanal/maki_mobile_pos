// FirestoreProductRepository.adjustStockAudited — the transactional stock
// adjustment with a stale-count guard + append-only audit record (spec
// 2026-09-04). No Firestore emulator wired into the vitest suite, so this
// fakes the 'firebase/firestore' SDK surface: runTransaction executes the
// callback against a stubbed `tx` whose get() returns a seeded product
// snapshot and whose update()/set() capture their payloads. Separate file
// from FirestoreProductRepository.test.ts per the task brief — its own
// vi.mock('firebase/firestore').
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { Firestore } from 'firebase/firestore';
import type { StockAdjustmentInput } from '@/domain/repositories/ProductRepository';
import {
  StaleOnHandError,
  ProductInactiveError,
  NegativeResultError,
} from '@/domain/products/adjustmentErrors';

interface FakeRef {
  path: string;
  id: string;
}

interface Write {
  kind: 'set' | 'update';
  path: string;
  data: Record<string, unknown>;
}

const state = vi.hoisted(() => ({
  writes: [] as Write[],
  autoIdSeq: 0,
  product: { isActive: true, quantity: 10 } as { isActive: boolean; quantity: number },
  productPath: 'products/prod-1',
}));

function makeRef(path: string): FakeRef {
  const segs = path.split('/');
  return { path, id: segs[segs.length - 1] };
}

vi.mock('firebase/firestore', () => ({
  addDoc: vi.fn(),
  collection: vi.fn((parent: unknown, ...segs: string[]) => {
    const parentPath = (parent as { path?: string } | undefined)?.path;
    const path = [parentPath, ...segs].filter(Boolean).join('/');
    return { __col: true, path };
  }),
  collectionGroup: vi.fn(),
  doc: vi.fn((parent: unknown, ...segs: string[]) => {
    if (segs.length === 0) {
      const col = parent as { path: string };
      state.autoIdSeq += 1;
      return makeRef(`${col.path}/auto${state.autoIdSeq}`);
    }
    return makeRef(segs.join('/'));
  }),
  getDoc: vi.fn(),
  getDocs: vi.fn(async () => ({ docs: [], empty: true })),
  increment: vi.fn((n: number) => ({ __increment: n })),
  limit: vi.fn(),
  onSnapshot: vi.fn(),
  orderBy: vi.fn(),
  query: vi.fn(),
  runTransaction: vi.fn(async (_db: unknown, cb: (tx: unknown) => Promise<unknown>) => {
    const tx = {
      get: vi.fn(async (ref: FakeRef) => {
        if (ref.path === state.productPath) {
          return { exists: () => true, data: () => ({ ...state.product }) };
        }
        return { exists: () => false, data: () => ({}) };
      }),
      set: vi.fn((ref: FakeRef, data: Record<string, unknown>) => {
        state.writes.push({ kind: 'set', path: ref.path, data });
      }),
      update: vi.fn((ref: FakeRef, data: Record<string, unknown>) => {
        state.writes.push({ kind: 'update', path: ref.path, data });
      }),
    };
    return cb(tx);
  }),
  serverTimestamp: vi.fn(() => 'SERVER_TIMESTAMP'),
  Timestamp: { fromDate: vi.fn((d: Date) => d) },
  updateDoc: vi.fn(),
  where: vi.fn(),
  writeBatch: vi.fn(),
}));

const { FirestoreProductRepository } = await import('./FirestoreProductRepository');

function baseInput(overrides: Partial<StockAdjustmentInput> = {}): StockAdjustmentInput {
  return {
    mode: 'add',
    quantity: 5,
    expectedOnHand: 10,
    reasonId: 'reason-1',
    reasonName: 'Damaged',
    note: null,
    ...overrides,
  };
}

describe('FirestoreProductRepository.adjustStockAudited', () => {
  beforeEach(() => {
    state.writes = [];
    state.autoIdSeq = 0;
    state.product = { isActive: true, quantity: 10 };
  });

  it('throws ProductInactiveError when the product is inactive, and writes nothing', async () => {
    state.product.isActive = false;
    const repo = new FirestoreProductRepository({} as unknown as Firestore);

    await expect(
      repo.adjustStockAudited('prod-1', baseInput(), 'user-1', 'Admin User'),
    ).rejects.toThrow(ProductInactiveError);
    expect(state.writes).toHaveLength(0);
  });

  it('throws StaleOnHandError carrying the CURRENT on-hand quantity when it does not match expectedOnHand, and writes nothing', async () => {
    state.product.quantity = 15; // dialog started from a stale 10
    const repo = new FirestoreProductRepository({} as unknown as Firestore);

    let caught: unknown;
    try {
      await repo.adjustStockAudited('prod-1', baseInput({ expectedOnHand: 10 }), 'user-1', 'Admin User');
    } catch (e) {
      caught = e;
    }
    expect(caught).toBeInstanceOf(StaleOnHandError);
    expect((caught as StaleOnHandError).currentOnHand).toBe(15);
    expect(state.writes).toHaveLength(0);
  });

  it('throws NegativeResultError when the resolved quantity would go negative, and writes nothing', async () => {
    state.product.quantity = 5;
    const repo = new FirestoreProductRepository({} as unknown as Firestore);

    await expect(
      repo.adjustStockAudited(
        'prod-1',
        baseInput({ mode: 'remove', quantity: 10, expectedOnHand: 5 }),
        'user-1',
        'Admin User',
      ),
    ).rejects.toThrow(NegativeResultError);
    expect(state.writes).toHaveLength(0);
  });

  it('happy path: writes the exact product-update key set and the exact audit-record field set, and returns before/after/delta', async () => {
    state.product = { isActive: true, quantity: 10 };
    const repo = new FirestoreProductRepository({} as unknown as Firestore);

    const result = await repo.adjustStockAudited(
      'prod-1',
      baseInput({ mode: 'add', quantity: 5, expectedOnHand: 10, reasonId: 'reason-1', reasonName: 'Damaged', note: 'crate dropped' }),
      'user-1',
      'Admin User',
    );

    expect(result).toEqual({ before: 10, after: 15, delta: 5 });

    const productWrite = state.writes.find((w) => w.kind === 'update' && w.path === 'products/prod-1');
    expect(productWrite).toBeDefined();
    expect(productWrite!.data).toEqual({
      quantity: 15,
      updatedAt: 'SERVER_TIMESTAMP',
      updatedBy: 'user-1',
      updatedByName: 'Admin User',
    });

    const recordWrite = state.writes.find((w) => w.kind === 'set' && w.path.startsWith('products/prod-1/stock_adjustments/'));
    expect(recordWrite).toBeDefined();
    expect(recordWrite!.data).toEqual({
      mode: 'add',
      quantity: 5,
      delta: 5,
      before: 10,
      after: 15,
      reasonId: 'reason-1',
      reasonName: 'Damaged',
      note: 'crate dropped',
      createdAt: 'SERVER_TIMESTAMP',
      createdBy: 'user-1',
      createdByName: 'Admin User',
    });
  });

  it('happy path with no actor name: omits updatedByName from the product update but still writes createdByName: null on the record', async () => {
    state.product = { isActive: true, quantity: 10 };
    const repo = new FirestoreProductRepository({} as unknown as Firestore);

    await repo.adjustStockAudited('prod-1', baseInput(), 'user-1', null);

    const productWrite = state.writes.find((w) => w.kind === 'update' && w.path === 'products/prod-1');
    expect(productWrite!.data).toEqual({
      quantity: 15,
      updatedAt: 'SERVER_TIMESTAMP',
      updatedBy: 'user-1',
    });

    const recordWrite = state.writes.find((w) => w.kind === 'set' && w.path.startsWith('products/prod-1/stock_adjustments/'));
    expect(recordWrite!.data).toMatchObject({ createdBy: 'user-1', createdByName: null });
  });

  it('set mode: resolves the after-quantity to the entered value directly', async () => {
    state.product = { isActive: true, quantity: 10 };
    const repo = new FirestoreProductRepository({} as unknown as Firestore);

    const result = await repo.adjustStockAudited(
      'prod-1',
      baseInput({ mode: 'set', quantity: 3, expectedOnHand: 10 }),
      'user-1',
      'Admin User',
    );

    expect(result).toEqual({ before: 10, after: 3, delta: -7 });
  });
});
