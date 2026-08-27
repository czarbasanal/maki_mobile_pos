// FirestoreProductRepository.create()'s auto-SKU path (peek-then-claim inside
// the create transaction). Mirrors
// test/data/repositories/product_repository_auto_sku_test.dart's four
// scenarios exactly (happy path, raced/pre-claimed skip-to-next, manual
// override leaves the registry untouched, category-full throws and writes
// nothing). There's no Firestore emulator wired into the vitest suite, so
// this fakes the 'firebase/firestore' SDK surface (same template as
// FirestoreCategoryRepository.test.ts / FirestoreSaleRepository.test.ts).
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { Firestore } from 'firebase/firestore';
import { where } from 'firebase/firestore';
import type { ProductCreateInput } from '@/domain/repositories/ProductRepository';

interface FakeRef {
  path: string;
  id: string;
  withConverter: () => FakeRef;
}

interface Write {
  kind: 'set' | 'update';
  path: string;
  data: Record<string, unknown>;
  options?: unknown;
}

const state = vi.hoisted(() => ({
  writes: [] as Write[],
  autoIdSeq: 0,
  registry: {} as Record<string, { nextSequence: number }>,
  claimedSkuPaths: new Set<string>(),
}));

function makeRef(path: string): FakeRef {
  const segs = path.split('/');
  const ref: FakeRef = { path, id: segs[segs.length - 1], withConverter: () => ref };
  return ref;
}

vi.mock('firebase/firestore', () => ({
  collection: vi.fn((_db: unknown, ...segs: string[]) => {
    const path = segs.join('/');
    const col = { __col: true, path, withConverter: () => col };
    return col;
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
  deleteField: vi.fn(() => 'DELETE_FIELD'),
  addDoc: vi.fn(),
  getDoc: vi.fn(async (ref: FakeRef) => ({
    exists: () => true,
    id: ref.id,
    data: () => {
      const write = state.writes.find((w) => w.kind === 'set' && w.path === ref.path);
      return {
        sku: (write?.data.sku as string | undefined) ?? '',
        name: 'Brake Pad',
        costCode: 'NBF',
        cost: 100,
        price: 150,
        quantity: 10,
        reorderLevel: 2,
        unit: 'pcs',
        supplierId: null,
        supplierName: null,
        isActive: true,
        createdAt: new Date(),
        updatedAt: null,
        createdBy: 'user-1',
        updatedBy: 'user-1',
        createdByName: 'User One',
        updatedByName: 'User One',
        searchKeywords: [],
        baseSku: null,
        variationNumber: null,
        barcodes: [],
        category: null,
        imageUrl: null,
        notes: null,
      };
    },
  })),
  getDocs: vi.fn(async () => ({ docs: [], empty: true })),
  increment: vi.fn((n: number) => ({ __increment: n })),
  limit: vi.fn(),
  onSnapshot: vi.fn(),
  orderBy: vi.fn(),
  query: vi.fn(),
  runTransaction: vi.fn(async (_db: unknown, cb: (tx: unknown) => Promise<void>) => {
    const tx = {
      get: vi.fn(async (ref: FakeRef) => {
        if (ref.path.startsWith('category_codes/')) {
          const r = state.registry[ref.path];
          return { exists: () => !!r, data: () => (r ? { nextSequence: r.nextSequence } : {}) };
        }
        if (ref.path.startsWith('product_skus/')) {
          return { exists: () => state.claimedSkuPaths.has(ref.path), data: () => ({}) };
        }
        return { exists: () => false, data: () => ({}) };
      }),
      set: vi.fn((ref: FakeRef, data: Record<string, unknown>, options?: unknown) => {
        state.writes.push({ kind: 'set', path: ref.path, data, options });
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
}));

const { FirestoreProductRepository } = await import('./FirestoreProductRepository');

function productInput(sku: string): ProductCreateInput {
  return {
    sku,
    name: 'Brake Pad',
    costCode: 'NBF',
    cost: 100,
    price: 150,
    quantity: 10,
    reorderLevel: 2,
    unit: 'pcs',
    supplierId: null,
    supplierName: null,
    isActive: true,
    createdBy: 'user-1',
    updatedBy: 'user-1',
    createdByName: 'User One',
    updatedByName: 'User One',
    baseSku: null,
    variationNumber: null,
    barcodes: [],
    sellingOptions: [],
    category: null,
    imageUrl: null,
    notes: null,
  };
}

function seedRegistry(code: string, nextSequence: number) {
  state.registry[`category_codes/${code}`] = { nextSequence };
}

describe('FirestoreProductRepository.create — auto-SKU (peek + claim-in-transaction)', () => {
  beforeEach(() => {
    state.writes = [];
    state.autoIdSeq = 0;
    state.registry = {};
    state.claimedSkuPaths = new Set();
  });

  it('auto path: happy case claims the peeked sku and advances the registry', async () => {
    const repo = new FirestoreProductRepository({} as unknown as Firestore);
    seedRegistry('0007', 1);

    const created = await repo.create(productInput('00070001'), 'user-1', '0007');

    expect(created.sku).toBe('00070001');

    const productWrite = state.writes.find(
      (w) => w.kind === 'set' && w.path.startsWith('products/'),
    );
    expect(productWrite?.data.sku).toBe('00070001');

    const claimWrite = state.writes.find((w) => w.path === 'product_skus/00070001');
    expect(claimWrite).toBeDefined();
    expect(claimWrite?.data.productId).toBe(productWrite?.path.split('/')[1]);

    const registryWrite = state.writes.find((w) => w.path === 'category_codes/0007');
    expect(registryWrite).toBeDefined();
    expect(registryWrite?.kind).toBe('update');
    expect(registryWrite?.data).toEqual({ nextSequence: 2 });
  });

  it('auto path: a peeked sku pre-claimed by a race skips to the next free sequence', async () => {
    const repo = new FirestoreProductRepository({} as unknown as Firestore);
    seedRegistry('0007', 1);
    state.claimedSkuPaths.add('product_skus/00070001');

    const created = await repo.create(productInput('00070001'), 'user-1', '0007');

    expect(created.sku).toBe('00070002');

    const claimWrite = state.writes.find((w) => w.path === 'product_skus/00070002');
    expect(claimWrite).toBeDefined();

    const registryWrite = state.writes.find((w) => w.path === 'category_codes/0007');
    expect(registryWrite?.data).toEqual({ nextSequence: 3 });
  });

  it('manual override: a sku that does not match the auto pattern saves as-is and leaves the registry untouched', async () => {
    const repo = new FirestoreProductRepository({} as unknown as Firestore);
    seedRegistry('0007', 1);

    const created = await repo.create(productInput('BRAKE-99'), 'user-1', '0007');

    expect(created.sku).toBe('BRAKE-99');

    const claimWrite = state.writes.find((w) => w.path === 'product_skus/BRAKE-99');
    expect(claimWrite).toBeDefined();

    expect(state.writes.find((w) => w.path === 'category_codes/0007')).toBeUndefined();
  });

  it('category-full: registry at 9999 and claimed throws and writes nothing', async () => {
    const repo = new FirestoreProductRepository({} as unknown as Firestore);
    seedRegistry('0007', 9999);
    state.claimedSkuPaths.add('product_skus/00079999');

    await expect(
      repo.create(productInput('00079999'), 'user-1', '0007'),
    ).rejects.toThrow('Category is full — split it into two categories.');

    expect(state.writes.filter((w) => w.path.startsWith('products/'))).toHaveLength(0);
    expect(state.writes.find((w) => w.path === 'category_codes/0007')).toBeUndefined();
  });

  it('category-full at the boundary: registry nextSequence already 10000 throws before composing a candidate and writes nothing', async () => {
    const repo = new FirestoreProductRepository({} as unknown as Firestore);
    seedRegistry('0007', 10000);

    await expect(
      repo.create(productInput('00070001'), 'user-1', '0007'),
    ).rejects.toThrow('Category is full — split it into two categories.');

    expect(state.writes.filter((w) => w.path.startsWith('products/'))).toHaveLength(0);
    expect(state.writes.find((w) => w.path.startsWith('product_skus/'))).toBeUndefined();
    expect(state.writes.find((w) => w.path === 'category_codes/0007')).toBeUndefined();
  });
});

describe('FirestoreProductRepository.create — searchKeywords follow the allocated sku', () => {
  beforeEach(() => {
    state.writes = [];
    state.autoIdSeq = 0;
    state.registry = {};
    state.claimedSkuPaths = new Set();
  });

  it('auto path: a shifted sku re-derives the keywords so the product is findable by it', async () => {
    const repo = new FirestoreProductRepository({} as unknown as Firestore);
    seedRegistry('0007', 1);
    state.claimedSkuPaths.add('product_skus/00070001');

    await repo.create(productInput('00070001'), 'user-1', '0007');

    const productWrite = state.writes.find(
      (w) => w.kind === 'set' && w.path.startsWith('products/'),
    );
    const keywords = productWrite?.data.searchKeywords as string[];
    expect(keywords).toContain('00070002');
    expect(keywords).not.toContain('00070001');
  });

  it('auto path: a shifted sku overrides caller-supplied preview keywords', async () => {
    // applyReceivedItems passes keywords built from the PREVIEW sku; they are
    // as stale as the preview itself once the scan moves on.
    const repo = new FirestoreProductRepository({} as unknown as Firestore);
    seedRegistry('0007', 1);
    state.claimedSkuPaths.add('product_skus/00070001');

    await repo.create(
      { ...productInput('00070001'), searchKeywords: ['00070001', 'brake'] },
      'user-1',
      '0007',
    );

    const productWrite = state.writes.find(
      (w) => w.kind === 'set' && w.path.startsWith('products/'),
    );
    const keywords = productWrite?.data.searchKeywords as string[];
    expect(keywords).toContain('00070002');
    expect(keywords).not.toContain('00070001');
  });
});

describe('FirestoreProductRepository.findByNameKey', () => {
  beforeEach(() => {
    vi.mocked(where).mockClear();
  });

  it('filters to baseSku == null so a variation can never be returned as its base', async () => {
    // A cost variation inherits its base's name/category, so it carries the
    // SAME nameKey. Without this filter, an unordered limit(1) query could
    // nondeterministically return the variation instead of the base.
    const repo = new FirestoreProductRepository({} as unknown as Firestore);
    await repo.findByNameKey('widget|hardware');
    expect(vi.mocked(where).mock.calls).toContainEqual(['baseSku', '==', null]);
  });
});
