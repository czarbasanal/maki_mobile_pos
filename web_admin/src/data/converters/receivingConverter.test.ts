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
      quantity: 10, unit: 'kg', unitCost: 180, unitPrice: null, costCode: 'AB-CD',
      isNewVariation: false, newProductId: null, notes: null, pendingNewProduct: null,
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

  it('falls back to completedAt when createdAt is missing', () => {
    const r = receivingConverter.fromFirestore(
      snap('rcv-4', {
        referenceNumber: 'RCV-20260608-004',
        status: 'completed',
        completedAt: new Date('2026-06-08T12:00:00Z'),
        createdBy: 'u1',
        createdByName: 'Czar',
      }),
      opts,
    );
    expect(r.createdAt).toEqual(new Date('2026-06-08T12:00:00Z'));
  });

  it('throws only when both createdAt and completedAt are missing', () => {
    expect(() =>
      receivingConverter.fromFirestore(
        snap('rcv-5', {
          referenceNumber: 'RCV-20260608-005',
          status: 'completed',
          createdBy: 'u1',
          createdByName: 'Czar',
        }),
        opts,
      ),
    ).toThrow(/createdAt/);
  });

  it('defaults a missing or unknown status to draft (matches mobile)', () => {
    const base = {
      referenceNumber: 'RCV-20260608-006',
      createdAt: new Date('2026-06-08T10:00:00Z'),
      createdBy: 'u1',
      createdByName: 'Czar',
    };
    const missing = receivingConverter.fromFirestore(snap('rcv-6', base), opts);
    expect(missing.status).toBe('draft');

    const unknown = receivingConverter.fromFirestore(
      snap('rcv-7', { ...base, status: 'archived' }),
      opts,
    );
    expect(unknown.status).toBe('draft');
  });
});

describe('receivingConverter — invoiceNumber/receivedOn', () => {
  it('round-trips both fields through toFirestore/fromFirestore', () => {
    const written = receivingConverter.toFirestore({
      id: 'rcv-8',
      referenceNumber: 'RCV-20260905-001',
      supplierId: null,
      supplierName: null,
      items: [],
      totalCost: 0,
      totalQuantity: 0,
      status: 'draft',
      notes: null,
      createdAt: new Date('2026-09-05T08:00:00Z'),
      completedAt: null,
      createdBy: 'u1',
      createdByName: 'Czar',
      completedBy: null,
      version: 0,
      invoiceNumber: 'INV-4471',
      receivedOn: '2026-09-05',
    } as never);
    expect(written).toMatchObject({ invoiceNumber: 'INV-4471', receivedOn: '2026-09-05' });

    const read = receivingConverter.fromFirestore(snap('rcv-8', { ...written, createdAt: new Date('2026-09-05T08:00:00Z') }), opts);
    expect(read.invoiceNumber).toBe('INV-4471');
    expect(read.receivedOn).toBe('2026-09-05');
  });

  it('defaults both to null on a doc written before the fields existed', () => {
    const r = receivingConverter.fromFirestore(
      snap('rcv-9', {
        referenceNumber: 'RCV-20260608-009',
        status: 'draft',
        createdAt: new Date('2026-06-08T10:00:00Z'),
        createdBy: 'u1',
        createdByName: 'Czar',
      }),
      opts,
    );
    expect(r.invoiceNumber).toBeNull();
    expect(r.receivedOn).toBeNull();
  });
});

describe('receivingConverter — unitPrice on items', () => {
  it('parses a stored unitPrice and defaults pre-field items to null', () => {
    const r = receivingConverter.fromFirestore(
      snap('r1', {
        items: [
          { id: 'i1', productId: 'p1', sku: 'A', name: 'A', quantity: 1, unit: 'pcs', unitCost: 100, unitPrice: 260, costCode: 'X', isNewVariation: true, newProductId: 'v1', notes: null },
          { id: 'i2', productId: 'p2', sku: 'B', name: 'B', quantity: 1, unit: 'pcs', unitCost: 50, costCode: 'X', isNewVariation: false, newProductId: null, notes: null },
        ],
        createdAt: new Date('2026-06-08T10:00:00Z'),
      }),
    );
    expect(r.items[0].unitPrice).toBe(260);
    expect(r.items[1].unitPrice).toBeNull();
  });
});
