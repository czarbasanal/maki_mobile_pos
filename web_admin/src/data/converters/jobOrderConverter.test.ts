import { describe, expect, it } from 'vitest';
import { Timestamp } from 'firebase/firestore';
import { jobOrderConverter } from './jobOrderConverter';
import { DiscountType } from '@/domain/enums/DiscountType';

const snap = (id: string, data: Record<string, unknown>) =>
  ({ id, exists: () => true, data: () => data }) as never;

const createdTs = Timestamp.fromDate(new Date('2026-02-01T00:00:00Z'));

describe('jobOrderConverter.fromFirestore', () => {
  it('parses items + labor + mechanic + discount + conversion fields', () => {
    const d = jobOrderConverter.fromFirestore(
      snap('d1', {
        name: 'Mr Cruz bike',
        items: [
          { id: 'i1', productId: 'p1', sku: 'A', name: 'Plug', unitPrice: 100, unitCost: 60, quantity: 2, discountValue: 0, unit: 'pcs' },
        ],
        laborLines: [{ id: 'l1', description: 'Tune-up', fee: 500 }],
        feeLines: [{ id: 'f1', name: 'Convenience fee', amount: 50 }],
        mechanicId: 'm1',
        mechanicName: 'Juan',
        motorcycleModel: 'Honda Click 125i',
        discountType: 'percentage',
        createdBy: 'u1',
        createdByName: 'Cashier',
        createdAt: createdTs,
        isConverted: false,
        convertedToSaleId: null,
        notes: null,
      }),
    );
    expect(d.id).toBe('d1');
    expect(d.name).toBe('Mr Cruz bike');
    expect(d.items).toHaveLength(1);
    expect(d.items[0]).toMatchObject({ id: 'i1', productId: 'p1', quantity: 2 });
    expect(d.laborLines).toEqual([{ id: 'l1', description: 'Tune-up', fee: 500 }]);
    expect(d.feeLines).toEqual([{ id: 'f1', name: 'Convenience fee', amount: 50 }]);
    expect(d.mechanicId).toBe('m1');
    expect(d.mechanicName).toBe('Juan');
    expect(d.motorcycleModel).toBe('Honda Click 125i');
    expect(d.discountType).toBe(DiscountType.percentage);
    expect(d.isConverted).toBe(false);
    expect(d.createdAt).toEqual(createdTs.toDate());
  });

  it('defaults a missing name and missing labor', () => {
    const d = jobOrderConverter.fromFirestore(snap('d2', { createdAt: createdTs }));
    expect(d.name).toBe('Unnamed Job Order');
    expect(d.laborLines).toEqual([]);
    expect(d.items).toEqual([]);
    expect(d.mechanicId).toBeNull();
    expect(d.isConverted).toBe(false);
  });

  it('defaults feeLines to [] for a legacy jobOrder written before shop fees existed', () => {
    const d = jobOrderConverter.fromFirestore(
      snap('d3', {
        name: 'Legacy jobOrder',
        laborLines: [{ id: 'l1', description: 'Tune-up', fee: 500 }],
        createdAt: createdTs,
      }),
    );
    expect(d.feeLines).toEqual([]);
  });
});
