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
  existingSaleIds: [] as string[],
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
        if (state.existingSaleIds.some((id) => ref.path === `sales/${id}`)) {
          return { exists: () => true, data: () => ({}) };
        }
        if (ref.path === 'settings/sale_counters') {
          return { exists: () => state.counterExists, data: () => state.counterData };
        }
        // 'job_orders' — the post-rename collection (FirestoreCollections
        // .jobOrders). This branch was unreachable while it read 'jobOrders/'.
        if (state.jobOrderDoc && ref.path.startsWith('job_orders/')) {
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
    motorcycleModel: null,
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

// The sale doc is written the same hand-picked way as the item docs below, so
// it drifts from the entity just as easily. Billing out a job order on web
// dropped `motorcycleModel` this way: mobile records the bike on the job
// order and carries it into the sale, web wrote a sale without it.
describe('FirestoreSaleRepository.create — job order carry-over', () => {
  beforeEach(() => {
    state.writes = [];
    state.autoIdSeq = 0;
    state.counterExists = false;
    state.counterData = {};
    state.jobOrderDoc = null;
    vi.useRealTimers();
  });

  it('persists motorcycleModel on the sale doc', async () => {
    const repo = new FirestoreSaleRepository({} as unknown as Firestore);

    state.jobOrderDoc = { exists: true, isConverted: false };

    await repo.create(
      { ...baseInput(), jobOrderId: 'jo-1', motorcycleModel: 'Honda Click 125i' },
      'actor-1',
    );

    const saleWrite = state.writes.find((w) => w.kind === 'set' && w.path.startsWith('sales/'));
    expect((saleWrite?.data as Record<string, unknown>).motorcycleModel).toBe('Honda Click 125i');
  });

  it('persists motorcycleModel as null (not omitted) for a walk-in sale', async () => {
    const repo = new FirestoreSaleRepository({} as unknown as Firestore);

    await repo.create(baseInput(), 'actor-1');

    const saleWrite = state.writes.find((w) => w.kind === 'set' && w.path.startsWith('sales/'));
    expect(saleWrite?.data as Record<string, unknown>).toHaveProperty('motorcycleModel', null);
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

  // Newest structural path in the branch: a resumed job order (or a web POS
  // ticket) can carry two DIFFERENT selling-option lines of the SAME
  // product (a By 6 and a By 3 of one Pulley Ball) into create(). The SDKs
  // compose multiple increment() writes against one doc correctly, but
  // nothing pinned that here — this test is the pin.
  it('persists two option lines of the same product as two item docs and issues two separate stock decrements', async () => {
    const repo = new FirestoreSaleRepository({} as unknown as Firestore);
    const input = baseInput();
    const by6Item = itemWithOption({
      id: 'i1',
      optionId: 'o1',
      optionLabel: 'By 6',
      optionPieces: 6,
      optionPrice: 600,
      unitPrice: 100,
      quantity: 6,
    });
    const by3Item = itemWithOption({
      id: 'i2',
      optionId: 'o2',
      optionLabel: 'By 3',
      optionPieces: 3,
      optionPrice: 330,
      unitPrice: 110,
      quantity: 3,
    });
    input.items = [by6Item, by3Item];

    await repo.create(input, 'actor-1');

    // Two independent item docs, each keeping its own option fields — a
    // wrong implementation that dedupes by productId or overwrites one line
    // with the other would leave only one write here.
    const itemWrites = state.writes.filter((w) => w.kind === 'set' && w.path.includes('/items/'));
    expect(itemWrites).toHaveLength(2);

    const by6Write = itemWrites.find((w) => (w.data as Record<string, unknown>).optionId === 'o1')
      ?.data as Record<string, unknown>;
    const by3Write = itemWrites.find((w) => (w.data as Record<string, unknown>).optionId === 'o2')
      ?.data as Record<string, unknown>;
    expect(by6Write).toMatchObject({ optionId: 'o1', optionLabel: 'By 6', optionPieces: 6, optionPrice: 600 });
    expect(by3Write).toMatchObject({ optionId: 'o2', optionLabel: 'By 3', optionPieces: 3, optionPrice: 330 });

    // Two separate stock decrements against the SAME product doc (products/p1)
    // — one per line — not a single combined decrement. A wrong
    // implementation that collapses same-productId lines into one update
    // would leave only one write here (or a wrong total).
    const stockWrites = state.writes.filter((w) => w.kind === 'update' && w.path === 'products/p1');
    expect(stockWrites).toHaveLength(2);
    const decrements = stockWrites
      .map((w) => ((w.data as Record<string, unknown>).quantity as { __increment: number }).__increment)
      .sort((a, b) => a - b);
    expect(decrements).toEqual([-6, -3].sort((a, b) => a - b));
  });
});

describe('FirestoreSaleRepository.create — idempotent sale id (duplicate-submit guard)', () => {
  beforeEach(() => {
    state.writes = [];
    state.autoIdSeq = 0;
    state.counterExists = false;
    state.counterData = {};
    state.jobOrderDoc = null;
    state.existingSaleIds = [];
  });

  it('uses the caller-provided checkout id as the sale doc id', async () => {
    const repo = new FirestoreSaleRepository({} as unknown as Firestore);
    await repo.create(baseInput(), 'c1', 'ticket-uuid-1');
    const saleWrite = state.writes.find((w) => w.path === 'sales/ticket-uuid-1');
    expect(saleWrite).toBeDefined();
    expect(state.writes.some((w) => w.path.startsWith('sales/ticket-uuid-1/items/'))).toBe(true);
  });

  it('a retry against an already-recorded id writes NOTHING and returns the recorded sale', async () => {
    state.existingSaleIds = ['ticket-uuid-1'];
    const repo = new FirestoreSaleRepository({} as unknown as Firestore);
    const sale = await repo.create(baseInput(), 'c1', 'ticket-uuid-1');
    expect(state.writes).toHaveLength(0); // no sale, no items, no counter, no stock decrement
    expect(sale.saleNumber).toBe('SALE-STUB'); // reloaded, not re-created
  });

  it('without a checkout id the auto-id path still works', async () => {
    const repo = new FirestoreSaleRepository({} as unknown as Firestore);
    await repo.create(baseInput(), 'c1');
    expect(state.writes.some((w) => w.path.startsWith('sales/auto'))).toBe(true);
  });
});

describe('FirestoreSaleRepository.create — labor-only / fee-only sales', () => {
  beforeEach(() => {
    state.writes = [];
    state.autoIdSeq = 0;
    state.counterExists = false;
    state.counterData = {};
    state.jobOrderDoc = null;
    state.existingSaleIds = [];
  });

  it('writes a labor-only sale (no product lines) instead of throwing', async () => {
    const repo = new FirestoreSaleRepository({} as unknown as Firestore);
    const input = {
      ...baseInput(),
      items: [] as SaleItem[],
      laborLines: [{ id: 'l1', description: 'Change oil', fee: 150 }],
      mechanicId: 'm1',
      mechanicName: 'Berto',
    };
    await repo.create(input, 'c1', 'ticket-labor-1');
    const saleWrite = state.writes.find((w) => w.path === 'sales/ticket-labor-1');
    expect(saleWrite).toBeDefined();
    // No item docs and no stock decrements for a partless ticket.
    expect(state.writes.some((w) => w.path.includes('/items/'))).toBe(false);
    expect(state.writes.some((w) => w.path.startsWith('products/'))).toBe(false);
  });

  it('still refuses a cart with nothing billable at all', async () => {
    const repo = new FirestoreSaleRepository({} as unknown as Firestore);
    const input = { ...baseInput(), items: [] as SaleItem[] };
    await expect(repo.create(input, 'c1')).rejects.toThrow('empty cart');
    expect(state.writes).toHaveLength(0);
  });
});

describe('FirestoreSaleRepository.watchToday — SHOP-day window', () => {
  it('queries the PHT day bounds, not the device-local midnight', async () => {
    const fb = await import('firebase/firestore');
    (fb.where as ReturnType<typeof vi.fn>).mockClear();
    const { shopStartOfDay, shopEndOfDay } = await import('@/domain/time/shopTime');
    const repo = new FirestoreSaleRepository({} as unknown as Firestore);
    repo.watchToday(() => {});
    const calls = (fb.where as ReturnType<typeof vi.fn>).mock.calls.filter(
      (c: unknown[]) => c[0] === 'createdAt',
    );
    expect(calls).toHaveLength(2);
    const now = new Date();
    const [geCall, leCall] = calls;
    // Timestamp.fromDate is mocked as identity, so the bound Dates come through.
    expect((geCall[2] as Date).getTime()).toBe(shopStartOfDay(now).getTime());
    expect((leCall[2] as Date).getTime()).toBe(shopEndOfDay(now).getTime());
  });
});

describe('FirestoreSaleRepository.create — auto job order for direct service sales', () => {
  beforeEach(() => {
    state.writes = [];
    state.autoIdSeq = 0;
    state.counterExists = false;
    state.counterData = {};
    state.jobOrderDoc = null;
    vi.useRealTimers();
  });

  it('a mechanic on a ticket-less sale records a billed JO in the same transaction', async () => {
    const repo = new FirestoreSaleRepository({} as unknown as Firestore);

    await repo.create(
      { ...baseInput(), mechanicId: 'm1', mechanicName: 'Jeric', motorcycleModel: 'Smash' },
      'actor-1',
      undefined,
      'JO-090326-004',
    );

    const joWrite = state.writes.find((w) => w.kind === 'set' && w.path.startsWith('job_orders/'));
    expect(joWrite).toBeDefined();
    const jo = joWrite!.data as Record<string, unknown>;
    expect(jo.name).toBe('JO-090326-004');
    expect(jo.isConverted).toBe(true);
    expect(jo.mechanicName).toBe('Jeric');
    expect(jo.motorcycleModel).toBe('Smash');
    expect(jo.createdBy).toBe('actor-1');

    // The sale links back to the freshly created ticket.
    const saleWrite = state.writes.find((w) => w.kind === 'set' && w.path.startsWith('sales/'));
    const joId = joWrite!.path.split('/')[1];
    expect((saleWrite!.data as Record<string, unknown>).jobOrderId).toBe(joId);
    expect(jo.convertedToSaleId).toBe(saleWrite!.path.split('/')[1]);
  });

  it('a plain retail sale (no mechanic, no motorcycle) never creates a ticket', async () => {
    const repo = new FirestoreSaleRepository({} as unknown as Firestore);

    await repo.create(baseInput(), 'actor-1', undefined, 'JO-090326-004');

    expect(state.writes.some((w) => w.path.startsWith('job_orders/'))).toBe(false);
  });

  it('billing out an EXISTING ticket never creates a second one', async () => {
    const repo = new FirestoreSaleRepository({} as unknown as Firestore);
    state.jobOrderDoc = { exists: true, isConverted: false };

    await repo.create(
      { ...baseInput(), jobOrderId: 'jo-1', mechanicId: 'm1', mechanicName: 'Jeric' },
      'actor-1',
      undefined,
      'JO-090326-004',
    );

    const joSets = state.writes.filter((w) => w.kind === 'set' && w.path.startsWith('job_orders/'));
    expect(joSets).toHaveLength(0); // the existing ticket is UPDATED, not re-created
    const joUpdate = state.writes.find((w) => w.kind === 'update' && w.path === 'job_orders/jo-1');
    expect(joUpdate).toBeDefined();
  });

  it('without a minted name (list still loading) the sale proceeds without a ticket', async () => {
    const repo = new FirestoreSaleRepository({} as unknown as Firestore);

    await repo.create(
      { ...baseInput(), mechanicId: 'm1', mechanicName: 'Jeric' },
      'actor-1',
      undefined,
      null,
    );

    expect(state.writes.some((w) => w.path.startsWith('job_orders/'))).toBe(false);
    const saleWrite = state.writes.find((w) => w.kind === 'set' && w.path.startsWith('sales/'));
    expect((saleWrite!.data as Record<string, unknown>).jobOrderId).toBeNull();
  });
});
