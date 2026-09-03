// No Firestore emulator in the vitest suite — fake the 'firebase/firestore'
// surface (same template as FirestoreMechanicRepository.test.ts).
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { Firestore } from 'firebase/firestore';

interface FakeRef {
  path: string;
  id: string;
  withConverter: () => FakeRef;
}

const state = vi.hoisted(() => ({
  deletes: [] as string[],
  adds: [] as Array<{ path: string; data: Record<string, unknown> }>,
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
      return makeRef(`${col.path}/auto1`);
    }
    return makeRef(segs.join('/'));
  }),
  addDoc: vi.fn(async (col: { path: string }, data: Record<string, unknown>) => {
    state.adds.push({ path: col.path, data });
    return makeRef(`${col.path}/new1`);
  }),
  getDoc: vi.fn(async () => ({ data: () => ({ id: 'new1', name: 'Intact' }) })),
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
}));

const { FirestoreTagRepository } = await import('./FirestoreTagRepository');

describe('FirestoreTagRepository', () => {
  beforeEach(() => {
    state.deletes = [];
    state.adds = [];
  });

  it('create writes into product_tags with color, null description, active + audit', async () => {
    const repo = new FirestoreTagRepository({} as unknown as Firestore);
    await repo.create({ name: 'Intact', color: 'green' }, 'u1');
    expect(state.adds).toHaveLength(1);
    expect(state.adds[0].path).toBe('product_tags');
    expect(state.adds[0].data).toMatchObject({
      name: 'Intact',
      color: 'green',
      description: null,
      isActive: true,
      createdBy: 'u1',
      updatedBy: 'u1',
    });
  });

  it('delete removes the tag doc by id', async () => {
    const repo = new FirestoreTagRepository({} as unknown as Firestore);
    await repo.delete('t1');
    expect(state.deletes).toContain('product_tags/t1');
  });
});
