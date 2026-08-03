// listPriceChangesInRange must carry the option fields (optionId/optionLabel/
// optionPieces) onto PriceChangeEntry — Task 19a. Before this fix the method
// built the entry object literal without them (unlike the sibling
// listPriceHistory, which already mapped them), so every row from this read
// path looked like a base entry regardless of what was actually stored in
// Firestore, and the (productId, optionId) grouping fix in
// priceChangeReport.ts would have had nothing to key off. There's no
// Firestore emulator wired into the vitest suite, so this fakes the
// 'firebase/firestore' SDK surface (same template as
// FirestoreProductRepository.test.ts).
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { Firestore } from 'firebase/firestore';

interface FakeDoc {
  id: string;
  data: () => Record<string, unknown>;
  ref: { parent: { parent: { id: string } } };
}

const state = vi.hoisted(() => ({
  docs: [] as FakeDoc[],
}));

vi.mock('firebase/firestore', () => ({
  collection: vi.fn(),
  collectionGroup: vi.fn(),
  doc: vi.fn(),
  deleteField: vi.fn(),
  addDoc: vi.fn(),
  getDoc: vi.fn(),
  getDocs: vi.fn(async () => ({ docs: state.docs })),
  increment: vi.fn(),
  limit: vi.fn(),
  onSnapshot: vi.fn(),
  orderBy: vi.fn(),
  query: vi.fn(),
  runTransaction: vi.fn(),
  serverTimestamp: vi.fn(),
  Timestamp: { fromDate: vi.fn((d: Date) => d) },
  updateDoc: vi.fn(),
  where: vi.fn(),
}));

const { FirestoreProductRepository } = await import('./FirestoreProductRepository');

function fakeDoc(id: string, productId: string, data: Record<string, unknown>): FakeDoc {
  return {
    id,
    data: () => data,
    ref: { parent: { parent: { id: productId } } },
  };
}

describe('FirestoreProductRepository.listPriceChangesInRange — option fields', () => {
  beforeEach(() => {
    state.docs = [];
  });

  it('carries optionId/optionLabel/optionPieces onto the returned entry', async () => {
    state.docs = [
      fakeDoc('ph1', 'p1', {
        price: 330,
        cost: 180,
        changedAt: new Date('2026-07-01T00:00:00Z'),
        changedBy: 'u1',
        reason: 'Option added',
        optionId: 'o2',
        optionLabel: 'By 3',
        optionPieces: 3,
      }),
    ];
    const repo = new FirestoreProductRepository({} as unknown as Firestore);

    const entries = await repo.listPriceChangesInRange(
      new Date('2026-07-01T00:00:00Z'),
      new Date('2026-07-31T23:59:59Z'),
    );

    expect(entries).toHaveLength(1);
    expect(entries[0].optionId).toBe('o2');
    expect(entries[0].optionLabel).toBe('By 3');
    expect(entries[0].optionPieces).toBe(3);
  });

  it('a base entry (no option keys in Firestore) maps to null option fields', async () => {
    state.docs = [
      fakeDoc('ph2', 'p1', {
        price: 120,
        cost: 60,
        changedAt: new Date('2026-07-01T00:00:00Z'),
        changedBy: 'u1',
        reason: 'Price update',
      }),
    ];
    const repo = new FirestoreProductRepository({} as unknown as Firestore);

    const entries = await repo.listPriceChangesInRange(
      new Date('2026-07-01T00:00:00Z'),
      new Date('2026-07-31T23:59:59Z'),
    );

    expect(entries[0].optionId).toBeNull();
    expect(entries[0].optionLabel).toBeNull();
    expect(entries[0].optionPieces).toBeNull();
  });
});
