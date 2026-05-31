import { describe, expect, it } from 'vitest';
import { saleConverter } from './saleConverter';

// Minimal QueryDocumentSnapshot stub — the converter only reads `.id`/`.data()`.
function snap(id: string, data: Record<string, unknown>) {
  return { id, data: () => data } as never;
}
const opts = {} as never;

describe('saleConverter.fromFirestore', () => {
  it('parses inline laborLines, mechanic, and a tenders map', () => {
    const sale = saleConverter.fromFirestore(
      snap('s1', {
        saleNumber: 'S-1',
        discountType: 'amount',
        paymentMethod: 'mixed',
        amountReceived: 650,
        changeGiven: 0,
        status: 'completed',
        cashierId: 'c1',
        cashierName: 'Cashier',
        createdAt: new Date('2026-05-30T10:00:00Z'),
        laborLines: [{ id: 'l1', description: 'Tune-up', fee: 450 }],
        mechanicId: 'mech-1',
        mechanicName: 'Juan',
        tenders: { cash: 400, gcash: 250 },
      }),
      opts,
    );

    expect(sale.laborLines).toHaveLength(1);
    expect(sale.laborLines[0]).toEqual({
      id: 'l1',
      description: 'Tune-up',
      fee: 450,
    });
    expect(sale.mechanicId).toBe('mech-1');
    expect(sale.mechanicName).toBe('Juan');
    expect(sale.paymentMethod).toBe('mixed');
    expect(sale.tenders).toEqual({ cash: 400, gcash: 250 });
  });

  it('keeps maya/salmon tenders and drops unknown keys', () => {
    const sale = saleConverter.fromFirestore(
      snap('s2', {
        paymentMethod: 'maya',
        status: 'completed',
        createdAt: new Date('2026-05-30T10:00:00Z'),
        tenders: { maya: 300, salmon: 100, bogus: 999 },
      }),
      opts,
    );
    expect(sale.paymentMethod).toBe('maya');
    expect(sale.tenders).toEqual({ maya: 300, salmon: 100 });
  });

  it('legacy doc without labor/mechanic/tenders defaults to []/null/{}', () => {
    const sale = saleConverter.fromFirestore(
      snap('s3', {
        paymentMethod: 'cash',
        status: 'completed',
        createdAt: new Date('2026-05-30T10:00:00Z'),
      }),
      opts,
    );
    expect(sale.laborLines).toEqual([]);
    expect(sale.mechanicId).toBeNull();
    expect(sale.mechanicName).toBeNull();
    expect(sale.tenders).toEqual({});
  });
});
