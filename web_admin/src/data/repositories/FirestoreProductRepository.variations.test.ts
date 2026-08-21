// The two reads behind the New Product form's variation offer:
//   findBySkuClaim   — resolve the product that a colliding SKU belongs to
//   nextVariationNumber — allocate the next `<base>-N`
// No Firestore emulator in the vitest suite, so this fakes the SDK surface the
// same way FirestoreProductRepository.test.ts does.
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { Firestore } from 'firebase/firestore';

interface FakeRef {
  path: string;
  id: string;
  withConverter: () => FakeRef;
}

const state = vi.hoisted(() => ({
  /** product_skus/<NORMALIZED> -> claim payload */
  claims: {} as Record<string, { productId: string }>,
  /** products/<id> -> doc data */
  products: {} as Record<string, Record<string, unknown>>,
  /** what a baseSku query returns */
  variationDocs: [] as Record<string, unknown>[],
  /** every `where` clause the repo built, so the query shape is assertable */
  whereCalls: [] as { field: string; op: string; value: unknown }[],
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
  doc: vi.fn((_parent: unknown, ...segs: string[]) => makeRef(segs.join('/'))),
  deleteField: vi.fn(),
  addDoc: vi.fn(),
  getDoc: vi.fn(async (ref: FakeRef) => {
    const claim = state.claims[ref.path];
    if (claim) return { exists: () => true, id: ref.id, data: () => claim };
    const prod = state.products[ref.path];
    if (prod) return { exists: () => true, id: ref.id, data: () => prod };
    return { exists: () => false, id: ref.id, data: () => undefined };
  }),
  getDocs: vi.fn(async () => ({
    docs: state.variationDocs.map((d) => ({ data: () => d })),
    size: state.variationDocs.length,
  })),
  increment: vi.fn(),
  limit: vi.fn(),
  onSnapshot: vi.fn(),
  orderBy: vi.fn(),
  query: vi.fn(),
  runTransaction: vi.fn(),
  serverTimestamp: vi.fn(() => 'SERVER_TIMESTAMP'),
  Timestamp: { fromDate: vi.fn((d: Date) => d) },
  updateDoc: vi.fn(),
  where: vi.fn((field: string, op: string, value: unknown) => {
    state.whereCalls.push({ field, op, value });
    return { field, op, value };
  }),
}));

const { FirestoreProductRepository } = await import('./FirestoreProductRepository');

function repo() {
  return new FirestoreProductRepository({} as unknown as Firestore);
}

beforeEach(() => {
  state.claims = {};
  state.products = {};
  state.variationDocs = [];
  state.whereCalls = [];
});

describe('findBySkuClaim', () => {
  it('resolves the product the claim points at', async () => {
    state.claims['product_skus/ABC123'] = { productId: 'p9' };
    state.products['products/p9'] = { sku: 'ABC123', name: 'Brake shoe' };

    const found = await repo().findBySkuClaim('ABC123');

    expect(found).toMatchObject({ sku: 'ABC123', name: 'Brake shoe' });
  });

  it('finds a case-different SKU, because the claim key is normalized', async () => {
    // The create transaction collides on the NORMALIZED key, so a lookup that
    // only matched verbatim would report "no such product" for a save that
    // just failed as a duplicate.
    state.claims['product_skus/ABC123'] = { productId: 'p9' };
    state.products['products/p9'] = { sku: 'ABC123', name: 'Brake shoe' };

    const found = await repo().findBySkuClaim('  abc123 ');

    expect(found).toMatchObject({ sku: 'ABC123' });
  });

  it('returns null when the SKU is unclaimed', async () => {
    expect(await repo().findBySkuClaim('NOPE')).toBeNull();
  });

  it('returns null when the claim dangles past a deleted product', async () => {
    state.claims['product_skus/ABC123'] = { productId: 'gone' };

    expect(await repo().findBySkuClaim('ABC123')).toBeNull();
  });
});

describe('nextVariationNumber', () => {
  it('queries the base, not the SKU string', async () => {
    await repo().nextVariationNumber('ABC123');

    expect(state.whereCalls).toContainEqual({
      field: 'baseSku',
      op: '==',
      value: 'ABC123',
    });
  });

  it('starts at 1 for a base with no variations', async () => {
    expect(await repo().nextVariationNumber('ABC123')).toBe(1);
  });

  it('takes the max so a deleted variation cannot collide', async () => {
    state.variationDocs = [{ variationNumber: 1 }, { variationNumber: 3 }];

    expect(await repo().nextVariationNumber('ABC123')).toBe(4);
  });
});
