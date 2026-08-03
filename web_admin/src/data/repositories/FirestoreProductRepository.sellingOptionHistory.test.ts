// Wires sellingOptionHistoryEvents (16a, domain/products/sellingOptions.ts)
// into FirestoreProductRepository.update()/updateProductWithClaims() — the
// admin product-save path. There's no Firestore emulator wired into the
// vitest suite, so this fakes the 'firebase/firestore' SDK surface (same
// template as FirestoreProductRepository.test.ts's auto-SKU suite).
//
// Every assertion reads the RAW write payload passed to addDoc (not a parsed
// PriceHistoryEntry), so "absent" vs "null" is actually distinguishable: a
// base entry must have NO optionId/optionLabel/optionPieces keys at all.
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { Firestore } from 'firebase/firestore';
import type { Product } from '@/domain/entities';
import type { SellingOption } from '@/domain/entities/SellingOption';
import type { ProductUpdateInput } from '@/domain/repositories/ProductRepository';

interface FakeRef {
  path: string;
  id: string;
  withConverter: () => FakeRef;
}

interface HistoryWrite {
  path: string;
  data: Record<string, unknown>;
}

interface DocWrite {
  kind: 'update' | 'set';
  path: string;
  data: Record<string, unknown>;
}

const state = vi.hoisted(() => ({
  historyWrites: [] as HistoryWrite[],
  docWrites: [] as DocWrite[],
  // The product `getById` should return when the repository reads the prior
  // state before diffing. Settable per test.
  priorProduct: null as Product | null,
}));

function makeRef(path: string): FakeRef {
  const segs = path.split('/');
  const ref: FakeRef = { path, id: segs[segs.length - 1], withConverter: () => ref };
  return ref;
}

vi.mock('firebase/firestore', () => ({
  collection: vi.fn((_db: unknown, ...segs: string[]) => {
    const path = segs.join('/');
    return { __col: true, path, withConverter: () => ({ __col: true, path }) };
  }),
  collectionGroup: vi.fn(),
  doc: vi.fn((parent: unknown, ...segs: string[]) => {
    if (segs.length === 0) {
      const col = parent as { path: string };
      return makeRef(`${col.path}/autoId`);
    }
    return makeRef(segs.join('/'));
  }),
  deleteField: vi.fn(() => 'DELETE_FIELD'),
  addDoc: vi.fn(async (col: { path: string }, data: Record<string, unknown>) => {
    state.historyWrites.push({ path: col.path, data });
    return makeRef(`${col.path}/ph${state.historyWrites.length}`);
  }),
  getDoc: vi.fn(async (_ref: FakeRef) => ({
    exists: () => state.priorProduct !== null,
    data: () => state.priorProduct,
  })),
  getDocs: vi.fn(async () => ({ docs: [] })),
  increment: vi.fn((n: number) => ({ __increment: n })),
  limit: vi.fn(),
  onSnapshot: vi.fn(),
  orderBy: vi.fn(),
  query: vi.fn(),
  runTransaction: vi.fn(async (_db: unknown, cb: (tx: unknown) => Promise<void>) => {
    const tx = {
      get: vi.fn(async (ref: FakeRef) => ({
        // Neither a SKU claim nor a barcode claim exists by default — the
        // SKU-changed scenarios below use a fresh `next` SKU.
        exists: () => false,
        data: () => ({}),
        id: ref.id,
      })),
      set: vi.fn((ref: FakeRef, data: Record<string, unknown>) => {
        state.docWrites.push({ kind: 'set', path: ref.path, data });
      }),
      update: vi.fn((ref: FakeRef, data: Record<string, unknown>) => {
        state.docWrites.push({ kind: 'update', path: ref.path, data });
      }),
      delete: vi.fn((_ref: FakeRef) => {}),
    };
    return cb(tx);
  }),
  serverTimestamp: vi.fn(() => 'SERVER_TIMESTAMP'),
  Timestamp: { fromDate: vi.fn((d: Date) => d) },
  updateDoc: vi.fn(async (ref: FakeRef, data: Record<string, unknown>) => {
    state.docWrites.push({ kind: 'update', path: ref.path, data });
  }),
  where: vi.fn(),
}));

const { FirestoreProductRepository } = await import('./FirestoreProductRepository');

const by3: SellingOption = { id: 'o2', label: 'By 3', pieces: 3, price: 330 };
const by6: SellingOption = { id: 'o1', label: 'By 6', pieces: 6, price: 600 };

function product(over: Partial<Product> = {}): Product {
  return {
    id: 'p1', sku: 'ABC1', name: 'Widget', costCode: 'AA', cost: 60, price: 100,
    quantity: 5, reorderLevel: 1, unit: 'pcs', supplierId: null, supplierName: null,
    isActive: true, createdAt: new Date(2026, 0, 1), updatedAt: null,
    createdBy: 'u1', updatedBy: 'u1', createdByName: 'Admin', updatedByName: 'Admin',
    searchKeywords: [], baseSku: null, variationNumber: null, barcodes: [],
    sellingOptions: [], category: null, imageUrl: null, notes: null,
    ...over,
  };
}

describe('FirestoreProductRepository.update — selling-option price history', () => {
  beforeEach(() => {
    state.historyWrites = [];
    state.docWrites = [];
    state.priorProduct = null;
  });

  it('adding an option writes one Option added entry with the set cost', async () => {
    state.priorProduct = product({ cost: 60, sellingOptions: [] });
    const repo = new FirestoreProductRepository({} as unknown as Firestore);

    await repo.update('p1', { sellingOptions: [by3] }, 'actor-1', true);

    expect(state.historyWrites).toHaveLength(1);
    const [write] = state.historyWrites;
    expect(write.data.reason).toBe('Option added');
    expect(write.data.price).toBe(330);
    expect(write.data.cost).toBe(180); // 3 * 60
    expect(write.data.optionId).toBe('o2');
    expect(write.data.optionLabel).toBe('By 3');
    expect(write.data.optionPieces).toBe(3);
  });

  it('removing an option writes Option removed with its last known price', async () => {
    state.priorProduct = product({ cost: 60, sellingOptions: [by3] });
    const repo = new FirestoreProductRepository({} as unknown as Firestore);

    await repo.update('p1', { sellingOptions: [] }, 'actor-1', true);

    expect(state.historyWrites).toHaveLength(1);
    expect(state.historyWrites[0].data).toMatchObject({
      reason: 'Option removed', price: 330, optionLabel: 'By 3',
    });
  });

  it('computes the option set cost from the NEW cost when cost changes in the same edit', async () => {
    state.priorProduct = product({ cost: 60, sellingOptions: [] });
    const repo = new FirestoreProductRepository({} as unknown as Firestore);

    await repo.update('p1', { cost: 100, sellingOptions: [by3] }, 'actor-1', true);

    expect(state.historyWrites).toHaveLength(1);
    expect(state.historyWrites[0].data.cost).toBe(300); // 3 * 100, not 3 * 60
  });

  it('several simultaneous option changes each produce their own entry', async () => {
    state.priorProduct = product({ cost: 10, sellingOptions: [by6, by3] });
    const repo = new FirestoreProductRepository({} as unknown as Firestore);

    // o1 price update, o2 removed.
    await repo.update('p1', { sellingOptions: [{ ...by6, price: 650 }] }, 'actor-1', true);

    expect(state.historyWrites).toHaveLength(2);
    expect(state.historyWrites.map((w) => w.data.reason).sort()).toEqual(
      ['Option removed', 'Price update'].sort(),
    );
  });

  it('identical sellingOptions writes nothing extra', async () => {
    state.priorProduct = product({ cost: 60, sellingOptions: [by3] });
    const repo = new FirestoreProductRepository({} as unknown as Firestore);

    await repo.update('p1', { name: 'Renamed', sellingOptions: [by3] }, 'actor-1', true);

    expect(state.historyWrites).toHaveLength(0);
  });

  it('includeSellingOptions:false never diffs, even if the patch carries a different sellingOptions array', async () => {
    state.priorProduct = product({ cost: 60, sellingOptions: [] });
    const repo = new FirestoreProductRepository({} as unknown as Firestore);

    await repo.update('p1', { sellingOptions: [by3] }, 'actor-1', false);

    expect(state.historyWrites).toHaveLength(0);
    // Also confirms no prior-read was needed: buildProductUpdate strips the
    // field for this tier, so the doc write itself never sees it either.
    expect(state.docWrites.some((w) => 'sellingOptions' in w.data)).toBe(false);
  });

  it('sellingOptions omitted from the patch (untouched field) writes nothing extra', async () => {
    state.priorProduct = product({ cost: 60, sellingOptions: [by3] });
    const repo = new FirestoreProductRepository({} as unknown as Firestore);
    const patch: ProductUpdateInput = { name: 'Renamed' };

    await repo.update('p1', patch, 'actor-1', true);

    expect(state.historyWrites).toHaveLength(0);
  });

  it('a product with no selling options at all produces no history writes from this repository method (unchanged from before this feature)', async () => {
    state.priorProduct = product({ cost: 60, price: 100, sellingOptions: [] });
    const repo = new FirestoreProductRepository({} as unknown as Firestore);

    await repo.update('p1', { price: 120, sellingOptions: [] }, 'actor-1', true);

    expect(state.historyWrites).toHaveLength(0);
  });
});

describe('FirestoreProductRepository.updateProductWithClaims — selling-option price history', () => {
  beforeEach(() => {
    state.historyWrites = [];
    state.docWrites = [];
    state.priorProduct = null;
  });

  it('also writes selling-option history when the SKU changes in the same save', async () => {
    state.priorProduct = product({ sku: 'OLD', cost: 60, sellingOptions: [] });
    const repo = new FirestoreProductRepository({} as unknown as Firestore);

    await repo.updateProductWithClaims(
      'p1',
      { sku: 'NEW', sellingOptions: [by3] },
      { old: 'OLD', next: 'NEW', changed: true },
      { old: [], next: [] },
      'actor-1',
      'Admin',
      true,
    );

    expect(state.historyWrites).toHaveLength(1);
    expect(state.historyWrites[0].data).toMatchObject({ reason: 'Option added', optionId: 'o2' });
  });
});

describe('FirestoreProductRepository.recordPriceChange — option fields', () => {
  beforeEach(() => {
    state.historyWrites = [];
  });

  it('writes optionId/optionLabel/optionPieces when supplied', async () => {
    const repo = new FirestoreProductRepository({} as unknown as Firestore);
    await repo.recordPriceChange('p1', {
      price: 330, cost: 180, changedBy: 'u1', reason: 'Option added',
      optionId: 'o2', optionLabel: 'By 3', optionPieces: 3,
    });

    expect(state.historyWrites).toHaveLength(1);
    expect(state.historyWrites[0].data).toMatchObject({
      optionId: 'o2', optionLabel: 'By 3', optionPieces: 3,
    });
  });

  it('omits the option keys entirely for a base entry — not present as null', async () => {
    const repo = new FirestoreProductRepository({} as unknown as Firestore);
    await repo.recordPriceChange('p1', {
      price: 150, cost: 60, changedBy: 'u1', reason: 'Price update',
    });

    expect(state.historyWrites).toHaveLength(1);
    const { data } = state.historyWrites[0];
    expect('optionId' in data).toBe(false);
    expect('optionLabel' in data).toBe(false);
    expect('optionPieces' in data).toBe(false);
  });
});
