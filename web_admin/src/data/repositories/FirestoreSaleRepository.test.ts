// FirestoreSaleRepository.create() writes several documents inside one
// transaction (sale, items, counter, stock decrement, optional job order
// conversion). There's no Firestore emulator wired into the vitest suite
// (unlike mobile's fake_cloud_firestore), so this test fakes the
// 'firebase/firestore' SDK surface just enough to pin *what* the
// transaction writes — in particular, that it now also merge-writes
// drawer_state/state.lastSaleDay beside the sale write (business-day
// rollover, Task 7).
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { Firestore } from 'firebase/firestore';
import type { Sale, SaleItem } from '@/domain/entities';
import { DiscountType, PaymentMethod, SaleStatus } from '@/domain/enums';
import { saleItemConverter } from '@/data/converters/saleItemConverter';

interface FakeRef {
  path: string;
  id: string;
  withConverter: () => FakeRef;
}

interface Write {
  kind: 'set' | 'update';
  path: string;
  data: unknown;
  options?: unknown;
}

const state = vi.hoisted(() => ({
  writes: [] as Write[],
  autoIdSeq: 0,
  counterExists: false,
  counterData: {} as Record<string, number>,
  jobOrderDoc: null as null | { exists: boolean; isConverted?: boolean },
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
  doc: vi.fn((parent: unknown, ...segs: string[]) => {
    if (segs.length === 0) {
      const col = parent as { path: string };
      state.autoIdSeq += 1;
      return makeRef(`${col.path}/auto${state.autoIdSeq}`);
    }
    return makeRef(segs.join('/'));
  }),
  getDoc: vi.fn(async (ref: FakeRef) => ({
    exists: () => true,
    id: ref.id,
    data: () => ({
      saleNumber: 'SALE-STUB',
      laborLines: [],
      feeLines: [],
      mechanicId: null,
      mechanicName: null,
      tenders: {},
      discountType: DiscountType.amount,
      paymentMethod: PaymentMethod.cash,
      amountReceived: 0,
      changeGiven: 0,
      status: SaleStatus.completed,
      cashierId: 'c1',
      cashierName: 'Cashier',
      createdAt: new Date(),
      updatedAt: null,
      jobOrderId: null,
      notes: null,
      voidedAt: null,
      voidedBy: null,
      voidedByName: null,
      voidReason: null,
    }),
  })),
  getDocs: vi.fn(async () => ({ docs: [] })),
  increment: vi.fn((n: number) => ({ __increment: n })),
  limit: vi.fn(),
  onSnapshot: vi.fn(),
  orderBy: vi.fn(),
  query: vi.fn(),
  runTransaction: vi.fn(async (_db: unknown, cb: (tx: unknown) => Promise<void>) => {
    const tx = {
      get: vi.fn(async (ref: FakeRef) => {
        if (ref.path === 'settings/sale_counters') {
          return { exists: () => state.counterExists, data: () => state.counterData };
        }
        if (state.jobOrderDoc && ref.path.startsWith('jobOrders/')) {
          const d = state.jobOrderDoc;
          return {
            exists: () => d.exists,
            get: (key: string) => (key === 'isConverted' ? d.isConverted : undefined),
          };
        }
        return { exists: () => false, data: () => ({}) };
      }),
      set: vi.fn((ref: FakeRef, data: unknown, options?: unknown) => {
        state.writes.push({ kind: 'set', path: ref.path, data, options });
      }),
      update: vi.fn((ref: FakeRef, data: unknown) => {
        state.writes.push({ kind: 'update', path: ref.path, data });
      }),
    };
    return cb(tx);
  }),
  serverTimestamp: vi.fn(() => 'SERVER_TIMESTAMP'),
  Timestamp: { fromDate: vi.fn((d: Date) => d) },
  where: vi.fn(),
}));

const { FirestoreSaleRepository } = await import('./FirestoreSaleRepository');

function baseInput(): Omit<Sale, 'id' | 'createdAt' | 'updatedAt'> {
  return {
    saleNumber: '',
    items: [
      {
        id: 'i1',
        productId: 'p1',
        sku: 'A',
        name: 'Plug',
        unitPrice: 100,
        unitCost: 60,
        quantity: 1,
        discountValue: 0,
        unit: 'pcs',
        optionId: null,
        optionLabel: null,
        optionPieces: null,
        optionPrice: null,
      },
    ],
    laborLines: [],
    feeLines: [],
    mechanicId: null,
    mechanicName: null,
    tenders: { cash: 100 },
    discountType: DiscountType.amount,
    paymentMethod: PaymentMethod.cash,
    amountReceived: 100,
    changeGiven: 0,
    status: SaleStatus.completed,
    cashierId: 'c1',
    cashierName: 'Cashier',
    jobOrderId: null,
    notes: null,
    voidedAt: null,
    voidedBy: null,
    voidedByName: null,
    voidReason: null,
  };
}

describe('FirestoreSaleRepository.create — drawer_state stamping', () => {
  beforeEach(() => {
    state.writes = [];
    state.autoIdSeq = 0;
    state.counterExists = false;
    state.counterData = {};
    state.jobOrderDoc = null;
    vi.useRealTimers();
  });

  it('merge-writes drawer_state/state.lastSaleDay inside the same transaction as the sale write', async () => {
    const repo = new FirestoreSaleRepository({} as unknown as Firestore);

    await repo.create(baseInput(), 'actor-1');

    const saleWrite = state.writes.find((w) => w.kind === 'set' && w.path.startsWith('sales/'));
    expect(saleWrite).toBeDefined();

    const drawerWrite = state.writes.find((w) => w.path === 'drawer_state/state');
    expect(drawerWrite).toBeDefined();
    expect(drawerWrite?.kind).toBe('set');
    expect(drawerWrite?.options).toEqual({ merge: true });
    expect(drawerWrite?.data).toEqual({ lastSaleDay: expect.any(Number) });
  });

  it('stamps lastSaleDay as the PH-day int, matching the date-line-crossing case', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-07-25T17:00:00Z')); // 17:00 UTC == 01:00 PH next day
    const repo = new FirestoreSaleRepository({} as unknown as Firestore);

    await repo.create(baseInput(), 'actor-1');

    const drawerWrite = state.writes.find((w) => w.path === 'drawer_state/state');
    expect(drawerWrite?.data).toEqual({ lastSaleDay: 20260726 });
  });
});

// Item docs are written with a hand-picked field list inside the transaction
// (tx.set on a converter-less ref — see the file header comment on why this
// duplication is intentionally *not* collapsed into `.withConverter`), so it
// can independently drift from saleItemConverter.toFirestore, which is what
// reads use. That drift is exactly what silently dropped the four selling-
// option fields (optionId/optionLabel/optionPieces/optionPrice) from every
// web-completed sale until this fix.
describe('FirestoreSaleRepository.create — item write shape (selling options)', () => {
  beforeEach(() => {
    state.writes = [];
    state.autoIdSeq = 0;
    state.counterExists = false;
    state.counterData = {};
    state.jobOrderDoc = null;
    vi.useRealTimers();
  });

  function itemWithOption(overrides: Partial<SaleItem> = {}): SaleItem {
    return {
      id: 'i1',
      productId: 'p1',
      sku: 'ABC-1',
      name: 'Pulley Ball',
      unitPrice: 110,
      unitCost: 60,
      quantity: 6,
      discountValue: 0,
      unit: 'pcs',
      optionId: 'o2',
      optionLabel: 'By 3',
      optionPieces: 3,
      optionPrice: 330,
      ...overrides,
    };
  }

  function findItemWrite() {
    return state.writes.find((w) => w.kind === 'set' && w.path.includes('/items/'));
  }

  it('writes exactly the field set saleItemConverter.toFirestore produces for the same item (pins the shape against future drift)', async () => {
    // Primary regression test: the transaction's hand-picked item write and
    // saleItemConverter.toFirestore are two independent lists of the same
    // fields. If a field is ever added to (or renamed in) the converter and
    // this call site isn't updated to match — the exact way selling options
    // were dropped — the sorted key sets stop matching and this fails.
    const repo = new FirestoreSaleRepository({} as unknown as Firestore);
    const input = baseInput();
    input.items = [itemWithOption()];

    await repo.create(input, 'actor-1');

    const itemWrite = findItemWrite();
    expect(itemWrite).toBeDefined();

    const converterShape = saleItemConverter.toFirestore(input.items[0]) as Record<string, unknown>;
    expect(Object.keys(itemWrite!.data as object).sort()).toEqual(Object.keys(converterShape).sort());
  });

  it('persists optionId/optionLabel/optionPieces/optionPrice for a line rung up through a selling option', async () => {
    const repo = new FirestoreSaleRepository({} as unknown as Firestore);
    const input = baseInput();
    input.items = [itemWithOption()];

    await repo.create(input, 'actor-1');

    const data = findItemWrite()?.data as Record<string, unknown>;
    expect(data.optionId).toBe('o2');
    expect(data.optionLabel).toBe('By 3');
    expect(data.optionPieces).toBe(3);
    expect(data.optionPrice).toBe(330);
  });

  it('persists the option fields as null (not omitted) for a line with no selling option', async () => {
    const repo = new FirestoreSaleRepository({} as unknown as Firestore);
    // baseInput()'s single item already carries optionId/optionLabel/
    // optionPieces/optionPrice: null — i.e. no selling option.
    const input = baseInput();

    await repo.create(input, 'actor-1');

    const data = findItemWrite()?.data as Record<string, unknown>;
    expect(data).toHaveProperty('optionId', null);
    expect(data).toHaveProperty('optionLabel', null);
    expect(data).toHaveProperty('optionPieces', null);
    expect(data).toHaveProperty('optionPrice', null);
  });
});
