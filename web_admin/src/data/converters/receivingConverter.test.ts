import { describe, expect, it } from 'vitest';
import { receivingConverter } from './receivingConverter';

// Minimal QueryDocumentSnapshot stub — the converter only reads `.id`/`.data()`.
function snap(id: string, data: Record<string, unknown>) {
  return { id, data: () => data } as never;
}
const opts = {} as never;

describe('receivingConverter.fromFirestore', () => {
  it('maps a completed receiving with items, supplier, and timestamps', () => {
    const r = receivingConverter.fromFirestore(
      snap('rcv-1', {
        referenceNumber: 'RCV-20260608-001',
        supplierId: 'sup-1',
        supplierName: 'Acme Supply',
        items: [
          {
            id: 'i1', productId: 'p1', sku: 'BANGUS-1KG', name: 'Bangus 1kg',
            quantity: 10, unit: 'kg', unitCost: 180, costCode: 'AB-CD',
            isNewVariation: false, newProductId: null, notes: null,
          },
        ],
        totalCost: 1800,
        totalQuantity: 10,
        status: 'completed',
        notes: null,
        createdAt: new Date('2026-06-08T10:00:00Z'),
        completedAt: new Date('2026-06-08T10:00:05Z'),
        createdBy: 'u1',
        createdByName: 'Czar',
        completedBy: 'u1',
      }),
      opts,
    );

    expect(r.id).toBe('rcv-1');
    expect(r.referenceNumber).toBe('RCV-20260608-001');
    expect(r.supplierName).toBe('Acme Supply');
    expect(r.items).toHaveLength(1);
    expect(r.items[0]).toEqual({
      id: 'i1', productId: 'p1', sku: 'BANGUS-1KG', name: 'Bangus 1kg',
      quantity: 10, unit: 'kg', unitCost: 180, costCode: 'AB-CD',
      isNewVariation: false, newProductId: null, notes: null,
    });
    expect(r.totalCost).toBe(1800);
    expect(r.totalQuantity).toBe(10);
    expect(r.status).toBe('completed');
    expect(r.createdAt).toEqual(new Date('2026-06-08T10:00:00Z'));
    expect(r.completedAt).toEqual(new Date('2026-06-08T10:00:05Z'));
  });

  it('defaults nullable supplier/notes/completion and empty items', () => {
    const r = receivingConverter.fromFirestore(
      snap('rcv-2', {
        referenceNumber: 'RCV-20260608-002',
        status: 'draft',
        totalCost: 0,
        totalQuantity: 0,
        createdAt: new Date('2026-06-08T11:00:00Z'),
        createdBy: 'u1',
        createdByName: 'Czar',
      }),
      opts,
    );

    expect(r.items).toEqual([]);
    expect(r.supplierId).toBeNull();
    expect(r.supplierName).toBeNull();
    expect(r.notes).toBeNull();
    expect(r.completedAt).toBeNull();
    expect(r.completedBy).toBeNull();
    expect(r.status).toBe('draft');
  });

  it('coerces a Firestore Timestamp-like createdAt', () => {
    const r = receivingConverter.fromFirestore(
      snap('rcv-3', {
        referenceNumber: 'RCV-20260608-003',
        status: 'completed',
        createdAt: { seconds: 1749376800, nanoseconds: 0 },
        createdBy: 'u1',
        createdByName: 'Czar',
      }),
      opts,
    );
    expect(r.createdAt).toBeInstanceOf(Date);
    expect(r.createdAt.getTime()).toBe(1749376800 * 1000);
  });
});
