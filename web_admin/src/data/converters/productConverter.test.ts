import { describe, expect, it } from 'vitest';
import { productConverter } from './productConverter';
import type { QueryDocumentSnapshot, DocumentData } from 'firebase/firestore';

function snap(data: Record<string, unknown>): QueryDocumentSnapshot<DocumentData> {
  return {
    id: 'p1',
    data: () => ({
      sku: 'ABC-1',
      name: 'Pulley Ball',
      costCode: 'NBF',
      cost: 60,
      price: 120,
      quantity: 12,
      reorderLevel: 3,
      unit: 'pcs',
      isActive: true,
      createdAt: new Date('2026-07-29'),
      ...data,
    }),
  } as unknown as QueryDocumentSnapshot<DocumentData>;
}

describe('productConverter selling options', () => {
  it('reads a missing sellingOptions field as an empty list', () => {
    expect(productConverter.fromFirestore(snap({})).sellingOptions).toEqual([]);
  });

  it('reads well-formed options', () => {
    const p = productConverter.fromFirestore(
      snap({ sellingOptions: [{ id: 'o1', label: 'By 6', pieces: 6, price: 600 }] }),
    );
    expect(p.sellingOptions).toEqual([{ id: 'o1', label: 'By 6', pieces: 6, price: 600 }]);
  });

  it('writes options back out', () => {
    const p = productConverter.fromFirestore(
      snap({ sellingOptions: [{ id: 'o1', label: 'By 6', pieces: 6, price: 600 }] }),
    );
    const out = productConverter.toFirestore(p) as Record<string, unknown>;
    expect(out.sellingOptions).toEqual([{ id: 'o1', label: 'By 6', pieces: 6, price: 600 }]);
  });
});

describe('productConverter tagIds', () => {
  it('reads a missing tagIds field as an empty list', () => {
    expect(productConverter.fromFirestore(snap({})).tagIds).toEqual([]);
  });

  it('reads well-formed tagIds', () => {
    const p = productConverter.fromFirestore(snap({ tagIds: ['t1', 't2'] }));
    expect(p.tagIds).toEqual(['t1', 't2']);
  });

  it('drops non-string entries from a malformed tagIds array', () => {
    const p = productConverter.fromFirestore(snap({ tagIds: ['t1', 7, null] }));
    expect(p.tagIds).toEqual(['t1']);
  });

  it('writes tagIds back out verbatim', () => {
    const p = productConverter.fromFirestore(snap({ tagIds: ['t1', 't2'] }));
    const out = productConverter.toFirestore(p) as Record<string, unknown>;
    expect(out.tagIds).toEqual(['t1', 't2']);
  });
});
