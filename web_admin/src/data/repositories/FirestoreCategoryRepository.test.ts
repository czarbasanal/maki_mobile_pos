// FirestoreCategoryRepository.create() assigns a sequential Code128 category
// code for CategoryKind.product ONLY, via a transaction mirroring
// lib/data/repositories/category_repository_impl.dart's createCategory
// (assignCode: true) exactly: category_codes/_counter {next}, registry doc
// category_codes/{code} {categoryId, nameSnapshot, assignedAt, nextSequence},
// and the category doc gains `code`. There's no Firestore emulator wired
// into the vitest suite, so this fakes the 'firebase/firestore' SDK surface
// (same template as FirestoreSaleRepository.test.ts).
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { Firestore } from 'firebase/firestore';
import { CategoryKind } from '@/domain/categories/categoryKind';

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
  counterExists: false,
  counterData: {} as Record<string, number>,
  addCalls: [] as { path: string; data: Record<string, unknown> }[],
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
  addDoc: vi.fn(async (col: { path: string }, data: Record<string, unknown>) => {
    state.addCalls.push({ path: col.path, data });
    state.autoIdSeq += 1;
    return makeRef(`${col.path}/auto${state.autoIdSeq}`);
  }),
  getDoc: vi.fn(async (ref: FakeRef) => ({
    exists: () => true,
    id: ref.id,
    data: () => ({
      name: 'Stub',
      isActive: true,
      createdAt: new Date(),
      updatedAt: null,
      createdBy: 'actor-1',
      updatedBy: 'actor-1',
      code: state.writes.find((w) => w.path === ref.path)?.data.code,
    }),
  })),
  getDocs: vi.fn(async () => ({ docs: [] })),
  onSnapshot: vi.fn(),
  runTransaction: vi.fn(async (_db: unknown, cb: (tx: unknown) => Promise<void>) => {
    const tx = {
      get: vi.fn(async (ref: FakeRef) => {
        if (ref.path === 'category_codes/_counter') {
          return { exists: () => state.counterExists, data: () => state.counterData };
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
  updateDoc: vi.fn(),
}));

const { FirestoreCategoryRepository } = await import('./FirestoreCategoryRepository');

describe('FirestoreCategoryRepository.create', () => {
  beforeEach(() => {
    state.writes = [];
    state.addCalls = [];
    state.autoIdSeq = 0;
    state.counterExists = false;
    state.counterData = {};
  });

  it('assigns code 0001 to the first product category, with registry + counter writes', async () => {
    const repo = new FirestoreCategoryRepository({} as unknown as Firestore);

    const created = await repo.create(CategoryKind.product, 'Filters', 'actor-1');

    const catWrite = state.writes.find(
      (w) => w.kind === 'set' && w.path.startsWith('product_categories/'),
    );
    expect(catWrite).toBeDefined();
    expect(catWrite?.data.code).toBe('0001');
    expect(created.code).toBe('0001');

    const registryWrite = state.writes.find((w) => w.path === 'category_codes/0001');
    expect(registryWrite).toBeDefined();
    expect(registryWrite?.data).toEqual({
      categoryId: catWrite?.path.split('/')[1],
      nameSnapshot: 'Filters',
      assignedAt: 'SERVER_TIMESTAMP',
      nextSequence: 1,
    });

    const counterWrite = state.writes.find((w) => w.path === 'category_codes/_counter');
    expect(counterWrite).toBeDefined();
    expect(counterWrite?.data).toEqual({ next: 2 });
  });

  it('assigns the next sequential code (0002) on a second create', async () => {
    state.counterExists = true;
    state.counterData = { next: 2 };
    const repo = new FirestoreCategoryRepository({} as unknown as Firestore);

    const created = await repo.create(CategoryKind.product, 'Oils', 'actor-1');

    expect(created.code).toBe('0002');
    const counterWrite = state.writes.find((w) => w.path === 'category_codes/_counter');
    expect(counterWrite?.data).toEqual({ next: 3 });
  });

  it('does not assign a code for non-product kinds — plain addDoc, no registry/counter', async () => {
    const repo = new FirestoreCategoryRepository({} as unknown as Firestore);

    const created = await repo.create(CategoryKind.unit, 'Box', 'actor-1');

    expect(state.addCalls).toHaveLength(1);
    expect(state.addCalls[0].data.code).toBeUndefined();
    expect(created.code).toBeUndefined();

    expect(state.writes.find((w) => w.path.startsWith('category_codes/'))).toBeUndefined();
  });
});
