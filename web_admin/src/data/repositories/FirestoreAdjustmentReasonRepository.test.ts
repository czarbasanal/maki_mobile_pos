// No Firestore emulator in the vitest suite — fake the 'firebase/firestore'
// surface (same template as FirestoreTagRepository.test.ts).
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { Firestore } from 'firebase/firestore';

interface FakeRef {
  path: string;
  id: string;
  withConverter: () => FakeRef;
}

interface FakeBatch {
  set: (ref: FakeRef, data: Record<string, unknown>) => void;
  commit: () => Promise<void>;
}

const state = vi.hoisted(() => ({
  deletes: [] as string[],
  adds: [] as Array<{ path: string; data: Record<string, unknown> }>,
  batchSets: [] as Array<{ path: string; data: Record<string, unknown> }>,
  batchCommitCount: 0,
}));

function makeRef(path: string): FakeRef {
  const segs = path.split('/');
  const ref: FakeRef = { path, id: segs[segs.length - 1], withConverter: () => ref };
  return ref;
}

function makeBatch(): FakeBatch {
  return {
    set: (ref: FakeRef, data: Record<string, unknown>) => {
      state.batchSets.push({ path: ref.path, data });
    },
    commit: async () => {
      state.batchCommitCount++;
    },
  };
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
      return makeRef(`${col.path}/auto1`);
    }
    return makeRef(segs.join('/'));
  }),
  addDoc: vi.fn(async (col: { path: string }, data: Record<string, unknown>) => {
    state.adds.push({ path: col.path, data });
    return makeRef(`${col.path}/new1`);
  }),
  getDoc: vi.fn(async () => ({ data: () => ({ id: 'new1', name: 'Delivery' }) })),
  getDocs: vi.fn(),
  limit: vi.fn(),
  query: vi.fn(),
  where: vi.fn(),
  onSnapshot: vi.fn(),
  serverTimestamp: vi.fn(() => 'SERVER_TIMESTAMP'),
  updateDoc: vi.fn(),
  deleteDoc: vi.fn(async (ref: FakeRef) => {
    state.deletes.push(ref.path);
  }),
  writeBatch: vi.fn(() => makeBatch()),
}));

const { FirestoreAdjustmentReasonRepository } = await import('./FirestoreAdjustmentReasonRepository');

describe('FirestoreAdjustmentReasonRepository', () => {
  beforeEach(() => {
    state.deletes = [];
    state.adds = [];
    state.batchSets = [];
    state.batchCommitCount = 0;
  });

  it('create writes into adjustment_reasons with requiresNote defaulted false + audit fields', async () => {
    const repo = new FirestoreAdjustmentReasonRepository({} as unknown as Firestore);
    await repo.create({ name: 'Delivery' }, 'u1');
    expect(state.adds).toHaveLength(1);
    expect(state.adds[0].path).toBe('adjustment_reasons');
    expect(state.adds[0].data).toMatchObject({
      name: 'Delivery',
      requiresNote: false,
      isActive: true,
      createdBy: 'u1',
      updatedBy: 'u1',
    });
  });

  it('delete removes the adjustment reason doc by id', async () => {
    const repo = new FirestoreAdjustmentReasonRepository({} as unknown as Firestore);
    await repo.delete('ar1');
    expect(state.deletes).toContain('adjustment_reasons/ar1');
  });

  it('seedDefaults stages exactly 6 sets in one batch with audit fields', async () => {
    const repo = new FirestoreAdjustmentReasonRepository({} as unknown as Firestore);
    await repo.seedDefaults('u1');
    expect(state.batchSets).toHaveLength(6);
    expect(state.batchCommitCount).toBe(1);
    // Verify all six seeds are present
    expect(state.batchSets[0].data).toMatchObject({ name: 'Delivery', requiresNote: false });
    expect(state.batchSets[1].data).toMatchObject({ name: 'Count correction', requiresNote: true });
    expect(state.batchSets[2].data).toMatchObject({ name: 'Damaged', requiresNote: true });
    expect(state.batchSets[3].data).toMatchObject({ name: 'Lost', requiresNote: true });
    expect(state.batchSets[4].data).toMatchObject({ name: 'Returned', requiresNote: false });
    expect(state.batchSets[5].data).toMatchObject({ name: 'Transfer', requiresNote: false });
    // Verify all have audit fields
    state.batchSets.forEach((set) => {
      expect(set.data).toMatchObject({
        isActive: true,
        createdAt: 'SERVER_TIMESTAMP',
        updatedAt: 'SERVER_TIMESTAMP',
        createdBy: 'u1',
        updatedBy: 'u1',
      });
    });
  });
});
