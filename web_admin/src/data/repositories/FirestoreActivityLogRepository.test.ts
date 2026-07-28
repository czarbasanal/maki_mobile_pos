// Pins the constraints FirestoreActivityLogRepository.list() actually asks
// Firestore for. There's no emulator wired into the vitest suite, so this
// fakes the 'firebase/firestore' surface (same template as
// FirestoreExpenseRepository.test.ts) and asserts on the recorded query.
//
// The load-bearing rule: selecting EVERY operation must emit no `type`
// constraint at all. It's the same result set either way, but an `in` clause
// listing all 24 types would drag the query onto the type+createdAt composite
// index (and Firestore caps `in` at 30 values).
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { Firestore } from 'firebase/firestore';
import { ActivityType, ALL_ACTIVITY_TYPES } from '@/domain/entities';

interface FakeConstraint {
  __where?: true;
  __orderBy?: true;
  __limit?: true;
  field?: string;
  op?: string;
  value?: unknown;
  dir?: string;
  n?: number;
}

const state = vi.hoisted(() => ({
  queryCalls: [] as { path: string; constraints: FakeConstraint[] }[],
  docsToReturn: [] as { id: string; data: Record<string, unknown> }[],
}));

vi.mock('firebase/firestore', () => ({
  collection: vi.fn((_db: unknown, ...segs: string[]) => {
    const path = segs.join('/');
    const col = { __col: true, path, withConverter: () => col };
    return col;
  }),
  getDocs: vi.fn(async (q: { path: string; constraints: FakeConstraint[] }) => {
    state.queryCalls.push(q);
    return { docs: state.docsToReturn.map((d) => ({ id: d.id, data: () => d.data })) };
  }),
  addDoc: vi.fn(async () => ({ id: 'new' })),
  limit: vi.fn((n: number): FakeConstraint => ({ __limit: true, n })),
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
  serverTimestamp: vi.fn(() => 'SERVER_TIMESTAMP'),
  Timestamp: { fromDate: vi.fn((d: Date) => ({ __ts: d.getTime() })) },
}));

const { FirestoreActivityLogRepository } = await import('./FirestoreActivityLogRepository');

function repo() {
  return new FirestoreActivityLogRepository({} as unknown as Firestore);
}

const typeConstraints = (cs: FakeConstraint[]) => cs.filter((c) => c.__where && c.field === 'type');

describe('FirestoreActivityLogRepository.list', () => {
  beforeEach(() => {
    state.queryCalls = [];
    state.docsToReturn = [];
  });

  it('reads user_logs newest-first with no constraints for an empty query', async () => {
    await repo().list();

    const q = state.queryCalls[0];
    expect(q.path).toBe('user_logs');
    expect(q.constraints.filter((c) => c.__where)).toHaveLength(0);
    expect(q.constraints.filter((c) => c.__limit)).toHaveLength(0);
    expect(q.constraints.find((c) => c.__orderBy)).toEqual({
      __orderBy: true,
      field: 'createdAt',
      dir: 'desc',
    });
  });

  it('sends an `in` constraint for a partial type selection', async () => {
    await repo().list({ types: [ActivityType.sale, ActivityType.voidSale] });

    expect(typeConstraints(state.queryCalls[0].constraints)).toEqual([
      { __where: true, field: 'type', op: 'in', value: ['sale', 'void_sale'] },
    ]);
  });

  it('sends NO type constraint when every operation is selected', async () => {
    await repo().list({ types: [...ALL_ACTIVITY_TYPES] });

    expect(typeConstraints(state.queryCalls[0].constraints)).toHaveLength(0);
  });

  it('keeps the type constraint when all but one operation is selected', async () => {
    // One short of the full set is still a real filter — the guard must not
    // over-reach and drop it.
    await repo().list({ types: ALL_ACTIVITY_TYPES.slice(0, -1) });

    expect(typeConstraints(state.queryCalls[0].constraints)).toHaveLength(1);
  });

  it('bounds the window inclusively and applies the cap', async () => {
    const start = new Date(2026, 6, 20, 0, 0, 0, 0);
    const end = new Date(2026, 6, 20, 23, 59, 59, 999);

    await repo().list({ start, end, limit: 500 });

    const cs = state.queryCalls[0].constraints;
    expect(cs).toContainEqual({
      __where: true,
      field: 'createdAt',
      op: '>=',
      value: { __ts: start.getTime() },
    });
    expect(cs).toContainEqual({
      __where: true,
      field: 'createdAt',
      op: '<=',
      value: { __ts: end.getTime() },
    });
    expect(cs).toContainEqual({ __limit: true, n: 500 });
  });

  // The fake's withConverter is a no-op, so this only pins the
  // "one entity per returned doc" mapping, not the converter itself
  // (activityLogConverter is exercised by its own callers).
  it('returns one row per returned doc', async () => {
    state.docsToReturn = [
      {
        id: 'log-1',
        data: {
          type: 'sale',
          action: 'Completed sale',
          userName: 'Tester',
          createdAt: new Date(2026, 6, 20, 9, 0),
        },
      },
    ];

    const rows = await repo().list();

    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ action: 'Completed sale', userName: 'Tester' });
  });
});
