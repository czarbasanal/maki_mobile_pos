// executeReceivePlan writes planned products with its own transaction body, so
// the auto-SKU claim-scan and barcode claims must live HERE too — receiving
// never goes through FirestoreProductRepository.create. Before this, an auto
// row's peeked SKU was written verbatim (a race = the whole receiving fails)
// and barcodes were written onto the product without claims (uniqueness guard
// bypassed). Fake Transaction/Firestore, same style as the repository tests.
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { Firestore, Transaction } from 'firebase/firestore';
import type { PlannedCreate } from './planReceive';
import { DuplicateBarcodeError, DuplicateSkuError } from '../errors';

interface FakeRef {
  path: string;
  id: string;
  withConverter: () => FakeRef;
}

const state = vi.hoisted(() => ({
  writes: [] as { kind: 'set' | 'update'; path: string; data: Record<string, unknown> }[],
  claimedSkuPaths: new Set<string>(),
  claimedBarcodePaths: new Set<string>(),
  registry: {} as Record<string, { nextSequence: number }>,
  autoId: 0,
}));

function makeRef(path: string): FakeRef {
  const segs = path.split('/');
  const ref: FakeRef = { path, id: segs[segs.length - 1], withConverter: () => ref };
  return ref;
}

vi.mock('firebase/firestore', () => ({
  collection: vi.fn((parent: unknown, ...segs: string[]) => {
    const base = (parent as { path?: string }).path;
    const path = base ? `${base}/${segs.join('/')}` : segs.join('/');
    const col = { __col: true, path, withConverter: () => col };
    return col;
  }),
  doc: vi.fn((parent: unknown, ...segs: string[]) => {
    if (segs.length === 0) {
      state.autoId += 1;
      return makeRef(`${(parent as { path: string }).path}/auto${state.autoId}`);
    }
    return makeRef(segs.join('/'));
  }),
  increment: vi.fn((n: number) => ({ __increment: n })),
  serverTimestamp: vi.fn(() => 'SERVER_TIMESTAMP'),
}));

const { executeReceivePlan } = await import('./executeReceivePlan');

function fakeTx(): Transaction {
  return {
    get: vi.fn(async (ref: FakeRef) => {
      if (ref.path.startsWith('category_codes/')) {
        const r = state.registry[ref.path];
        return { exists: () => !!r, data: () => (r ? { nextSequence: r.nextSequence } : {}) };
      }
      if (ref.path.startsWith('product_skus/')) {
        return { exists: () => state.claimedSkuPaths.has(ref.path), data: () => ({}) };
      }
      if (ref.path.startsWith('product_barcodes/')) {
        return { exists: () => state.claimedBarcodePaths.has(ref.path), data: () => ({}) };
      }
      return { exists: () => false, data: () => ({}) };
    }),
    set: vi.fn((ref: FakeRef, data: Record<string, unknown>) => {
      state.writes.push({ kind: 'set', path: ref.path, data });
    }),
    update: vi.fn((ref: FakeRef, data: Record<string, unknown>) => {
      state.writes.push({ kind: 'update', path: ref.path, data });
    }),
  } as unknown as Transaction;
}

function planned(over: Omit<Partial<PlannedCreate>, 'input'> & { input?: Partial<PlannedCreate['input']> } = {}): PlannedCreate {
  return {
    productId: 'p-new-1',
    autoSkuCategoryCode: null,
    priceHistory: { price: 130, cost: 90, reason: 'Initial price' },
    ...over,
    input: {
      sku: 'SQ-1', name: 'Squid', costCode: 'A', cost: 90, price: 130,
      quantity: 3, reorderLevel: 1, unit: 'kg', supplierId: null, supplierName: null,
      isActive: true, createdBy: 'u1', updatedBy: 'u1', createdByName: 'U', updatedByName: 'U',
      baseSku: null, variationNumber: null, barcodes: [], sellingOptions: [],
      category: null, imageUrl: null, notes: null,
      ...(over.input ?? {}),
    } as PlannedCreate['input'],
  };
}

const plan = (creates: PlannedCreate[]) => ({
  creates, increments: new Map<string, number>(), items: [], newProducts: creates.length,
  variations: 0, received: creates.length,
});

const actor = { id: 'u1', name: 'U' };

beforeEach(() => {
  state.writes = [];
  state.claimedSkuPaths = new Set();
  state.claimedBarcodePaths = new Set();
  state.registry = {};
  state.autoId = 0;
});

describe('executeReceivePlan — auto-SKU scan', () => {
  it('claims the peeked SKU when it is still free and advances the registry', async () => {
    state.registry['category_codes/0007'] = { nextSequence: 5 };

    await executeReceivePlan(fakeTx(), {} as Firestore, plan([
      planned({ autoSkuCategoryCode: '0007', input: { sku: '00070005' } }),
    ]), actor);

    const productWrite = state.writes.find((w) => w.path.startsWith('products/'));
    expect(productWrite?.data.sku).toBe('00070005');
    expect(state.writes.some((w) => w.path === 'product_skus/00070005')).toBe(true);
    const reg = state.writes.find((w) => w.path === 'category_codes/0007');
    expect(reg?.data.nextSequence).toBe(6);
  });

  it('scans past a raced claim instead of failing the whole receiving', async () => {
    // The preview was peeked while the entry form was open; someone else took
    // 0005 before Receive was pressed. Manual SKUs abort atomically on a
    // collision — auto rows must walk forward instead.
    state.registry['category_codes/0007'] = { nextSequence: 5 };
    state.claimedSkuPaths.add('product_skus/00070005');

    await executeReceivePlan(fakeTx(), {} as Firestore, plan([
      planned({ autoSkuCategoryCode: '0007', input: { sku: '00070005' } }),
    ]), actor);

    const productWrite = state.writes.find((w) => w.path.startsWith('products/'));
    expect(productWrite?.data.sku).toBe('00070006');
    const reg = state.writes.find((w) => w.path === 'category_codes/0007');
    expect(reg?.data.nextSequence).toBe(7);
  });

  it('a manual SKU still aborts atomically when its claim is taken', async () => {
    state.claimedSkuPaths.add('product_skus/SQ-1');

    await expect(
      executeReceivePlan(fakeTx(), {} as Firestore, plan([planned()]), actor),
    ).rejects.toThrow(DuplicateSkuError);
    expect(state.writes).toHaveLength(0);
  });
});

describe('executeReceivePlan — barcode claims', () => {
  it('claims each barcode alongside the product', async () => {
    await executeReceivePlan(fakeTx(), {} as Firestore, plan([
      planned({ input: { barcodes: ['4800111222333'] } }),
    ]), actor);

    const claim = state.writes.find((w) => w.path === 'product_barcodes/4800111222333');
    expect(claim).toBeDefined();
    expect(claim?.data.productId).toBe('p-new-1');
  });

  it('aborts the whole receiving when a barcode is already claimed', async () => {
    state.claimedBarcodePaths.add('product_barcodes/4800111222333');

    await expect(
      executeReceivePlan(fakeTx(), {} as Firestore, plan([
        planned({ input: { barcodes: ['4800111222333'] } }),
      ]), actor),
    ).rejects.toThrow(DuplicateBarcodeError);
    expect(state.writes).toHaveLength(0);
  });
});
