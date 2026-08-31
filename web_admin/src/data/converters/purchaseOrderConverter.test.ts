import { describe, expect, it } from 'vitest';
import { Timestamp } from 'firebase/firestore';
import { purchaseOrderConverter } from './purchaseOrderConverter';

const snap = (id: string, data: Record<string, unknown>) =>
  ({ id, exists: () => true, data: () => data }) as never;

const createdTs = Timestamp.fromDate(new Date('2026-08-31T02:00:00Z'));

describe('purchaseOrderConverter', () => {
  it('parses a buying list: no supplier on the order, one per line', () => {
    const po = purchaseOrderConverter.fromFirestore(
      snap('po1', {
        referenceNumber: 'PO-20260831-001',
        supplierId: null,
        items: [
          { id: 'i1', productId: 'p1', sku: 'A', name: 'Tire', quantity: 6,
            unit: 'pcs', unitCost: 670, costCode: 'X',
            supplierId: 's1', supplierName: 'Maxxis' },
          { id: 'i2', productId: 'p2', sku: 'B', name: 'Oil filter', quantity: 4,
            unit: 'pcs', unitCost: 95, costCode: 'X' },
        ],
        totalCost: 4400,
        totalQuantity: 10,
        status: 'ordered',
        createdAt: createdTs,
        createdByName: 'Czar',
      }),
    );

    expect(po.supplierId).toBeNull();
    expect(po.items[0].supplierName).toBe('Maxxis');
    // Not yet decided on the road — absent, not empty string.
    expect(po.items[1].supplierId).toBeNull();
    expect(po.status).toBe('ordered');
  });

  it('reads an order mobile wrote, which has no per-line supplier', () => {
    const po = purchaseOrderConverter.fromFirestore(
      snap('po2', {
        referenceNumber: 'PO-1',
        supplierId: 's9',
        supplierName: 'Bando',
        items: [{ id: 'i1', productId: 'p1', sku: 'A', name: 'Belt', quantity: 2 }],
        createdAt: createdTs,
      }),
    );

    expect(po.supplierName).toBe('Bando');
    expect(po.items[0].supplierId).toBeNull();
    expect(po.status).toBe('draft');
  });

  it('is read-only', () => {
    expect(() => (purchaseOrderConverter.toFirestore as () => unknown)()).toThrow();
  });
});
