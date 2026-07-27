// Covers FirestoreExpenseRepository's CRUD + list() range/category filtering.
// There's no Firestore emulator wired into the vitest suite, so this fakes
// the 'firebase/firestore' SDK surface (same template as
// FirestoreCategoryRepository.test.ts / FirestoreSaleRepository.test.ts).
// list() filters on Expense.date (not createdAt) — matching the mobile
// ExpenseRepositoryImpl.getExpenses query — so the fake's `where`/`orderBy`
// mocks just record the constraints passed and getDocs returns canned docs;
// the assertions pin *what* gets asked for.
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { Firestore } from 'firebase/firestore';

interface FakeRef {
  path: string;
  id: string;
  withConverter: () => FakeRef;
}

interface Write {
  kind: 'set' | 'update';
  path: string;
  data: Record<string, unknown>;
}

interface FakeConstraint {
  __where?: true;
  __orderBy?: true;
  field: string;
  op?: string;
  value?: unknown;
  dir?: string;
}

const state = vi.hoisted(() => ({
  writes: [] as Write[],
  addCalls: [] as { path: string; data: Record<string, unknown> }[],
  deletes: [] as string[],
  autoIdSeq: 0,
  queryCalls: [] as { path: string; constraints: FakeConstraint[] }[],
  docsToReturn: [] as { id: string; data: Record<string, unknown> }[],
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
  getDoc: vi.fn(async (ref: FakeRef) => {
    const write = state.writes.find((w) => w.path === ref.path);
    return {
      exists: () => !!write,
      id: ref.id,
      // Simulates what a real FirestoreDataConverter.fromFirestore would
      // return (entity shape, `id` set from the snapshot) — the fake doesn't
      // invoke the real converter, so it hand-shapes the same result.
      data: () => (write ? { ...write.data, id: ref.id } : undefined),
    };
  }),
  getDocs: vi.fn(async (q: { path: string; constraints: FakeConstraint[] }) => {
    state.queryCalls.push(q);
    return { docs: state.docsToReturn.map((d) => ({ id: d.id, data: () => d.data })) };
  }),
  onSnapshot: vi.fn(),
  orderBy: vi.fn((field: string, dir: string): FakeConstraint => ({ __orderBy: true, field, dir })),
  where: vi.fn((field: string, op: string, value: unknown): FakeConstraint => ({
    __where: true,
    field,
    op,
    value,
  })),
  query: vi.fn((col: { path: string }, ...constraints: FakeConstraint[]) => ({
    path: col.path,
    constraints,
  })),
  setDoc: vi.fn(async (ref: FakeRef, data: Record<string, unknown>) => {
    state.writes.push({ kind: 'set', path: ref.path, data });
  }),
  updateDoc: vi.fn(async (ref: FakeRef, data: Record<string, unknown>) => {
    state.writes.push({ kind: 'update', path: ref.path, data });
  }),
  deleteDoc: vi.fn(async (ref: FakeRef) => {
    state.deletes.push(ref.path);
  }),
  serverTimestamp: vi.fn(() => 'SERVER_TIMESTAMP'),
  Timestamp: { fromDate: vi.fn((d: Date) => ({ __ts: d.getTime() })) },
}));

const { FirestoreExpenseRepository } = await import('./FirestoreExpenseRepository');

function baseData(overrides: Record<string, unknown> = {}) {
  return {
    description: 'Fuel',
    amount: 500,
    category: 'Transportation',
    date: new Date('2026-07-10T00:00:00.000Z'),
    notes: null,
    receiptNumber: null,
    receiptImageUrl: null,
    createdAt: new Date('2026-07-10T00:00:00.000Z'),
    updatedAt: null,
    createdBy: 'actor-1',
    createdByName: 'Cashier',
    updatedBy: null,
    ...overrides,
  };
}

describe('FirestoreExpenseRepository', () => {
  beforeEach(() => {
    state.writes = [];
    state.addCalls = [];
    state.deletes = [];
    state.autoIdSeq = 0;
    state.queryCalls = [];
    state.docsToReturn = [];
  });

  describe('newExpenseId', () => {
    it('pre-allocates a doc id under the expenses collection', () => {
      const repo = new FirestoreExpenseRepository({} as unknown as Firestore);
      const id = repo.newExpenseId();
      expect(id).toBe('auto1');
    });
  });

  describe('create', () => {
    it('auto-generates an id when none is preset', async () => {
      const repo = new FirestoreExpenseRepository({} as unknown as Firestore);

      const created = await repo.create(
        { ...baseData() } as never,
        'actor-1',
        'Cashier',
      );

      const write = state.writes.find((w) => w.kind === 'set' && w.path.startsWith('expenses/'));
      expect(write).toBeDefined();
      expect(write?.data.description).toBe('Fuel');
      expect(write?.data.createdAt).toBe('SERVER_TIMESTAMP');
      expect(created.id).toBe(write?.path.split('/')[1]);
    });

    it('lands the doc on a preset id (upload-before-create pattern)', async () => {
      const repo = new FirestoreExpenseRepository({} as unknown as Firestore);

      const created = await repo.create(
        { ...baseData({ receiptImageUrl: 'https://x/receipt.jpg' }), id: 'preset-1' } as never,
        'actor-1',
        'Cashier',
      );

      expect(state.writes.some((w) => w.kind === 'set' && w.path === 'expenses/preset-1')).toBe(
        true,
      );
      expect(created.id).toBe('preset-1');
      expect(created.receiptImageUrl).toBe('https://x/receipt.jpg');
    });
  });

  describe('update', () => {
    it('updates only the provided fields, stamping updatedBy/updatedAt', async () => {
      const repo = new FirestoreExpenseRepository({} as unknown as Firestore);

      await repo.update('e1', { amount: 750 }, 'actor-2');

      const write = state.writes.find((w) => w.kind === 'update' && w.path === 'expenses/e1');
      expect(write).toBeDefined();
      expect(write?.data).toEqual({
        amount: 750,
        updatedBy: 'actor-2',
        updatedAt: 'SERVER_TIMESTAMP',
      });
    });
  });

  describe('delete', () => {
    it('deletes the expense doc by id', async () => {
      const repo = new FirestoreExpenseRepository({} as unknown as Firestore);

      await repo.delete('e1');

      expect(state.deletes).toContain('expenses/e1');
    });
  });

  describe('getById', () => {
    it('returns null when the doc does not exist', async () => {
      const repo = new FirestoreExpenseRepository({} as unknown as Firestore);

      const result = await repo.getById('missing');

      expect(result).toBeNull();
    });
  });

  describe('list', () => {
    it('queries by date range + category, ordered by date desc', async () => {
      state.docsToReturn = [{ id: 'e1', data: baseData() }];
      const repo = new FirestoreExpenseRepository({} as unknown as Firestore);
      const start = new Date('2026-07-01T00:00:00.000Z');
      const end = new Date('2026-07-31T23:59:59.999Z');

      const results = await repo.list({ start, end, category: 'Transportation' });

      expect(results).toHaveLength(1);
      expect(results[0].description).toBe('Fuel');

      const q = state.queryCalls[0];
      expect(q.path).toBe('expenses');
      const fields = q.constraints.map((c) => ({ field: c.field, op: c.op, dir: c.dir }));
      expect(fields).toContainEqual({ field: 'date', op: '>=', dir: undefined });
      expect(fields).toContainEqual({ field: 'date', op: '<=', dir: undefined });
      expect(fields).toContainEqual({ field: 'category', op: '==', dir: undefined });
      expect(fields).toContainEqual({ field: 'date', op: undefined, dir: 'desc' });

      const startConstraint = q.constraints.find(
        (c) => c.__where && c.field === 'date' && c.op === '>=',
      );
      expect(startConstraint?.value).toEqual({ __ts: start.getTime() });
    });

    it('omits category/range constraints when not provided', async () => {
      state.docsToReturn = [];
      const repo = new FirestoreExpenseRepository({} as unknown as Firestore);

      await repo.list();

      const q = state.queryCalls[0];
      const whereConstraints = q.constraints.filter((c) => c.__where);
      expect(whereConstraints).toHaveLength(0);
      const orderConstraint = q.constraints.find((c) => c.__orderBy);
      expect(orderConstraint).toEqual({ __orderBy: true, field: 'date', dir: 'desc' });
    });
  });
});
