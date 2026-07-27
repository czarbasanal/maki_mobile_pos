// Covers FirestoreMechanicRepository.delete() only. There's no Firestore
// emulator wired into the vitest suite, so this fakes the 'firebase/firestore'
// SDK surface (same template as FirestoreCategoryRepository.test.ts).
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { Firestore } from 'firebase/firestore';

interface FakeRef {
  path: string;
  id: string;
  withConverter: () => FakeRef;
}

const state = vi.hoisted(() => ({
  deletes: [] as string[],
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
  addDoc: vi.fn(),
  getDoc: vi.fn(),
  onSnapshot: vi.fn(),
  serverTimestamp: vi.fn(() => 'SERVER_TIMESTAMP'),
  updateDoc: vi.fn(),
  deleteDoc: vi.fn(async (ref: FakeRef) => {
    state.deletes.push(ref.path);
  }),
}));

const { FirestoreMechanicRepository } = await import('./FirestoreMechanicRepository');

describe('FirestoreMechanicRepository.delete', () => {
  beforeEach(() => {
    state.deletes = [];
  });

  it('deletes the mechanic doc by id', async () => {
    const repo = new FirestoreMechanicRepository({} as unknown as Firestore);

    await repo.delete('m1');

    expect(state.deletes).toContain('mechanics/m1');
  });
});
