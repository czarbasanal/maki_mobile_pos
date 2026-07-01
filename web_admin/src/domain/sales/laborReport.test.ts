import { describe, expect, it } from 'vitest';
import { DiscountType, PaymentMethod, SaleStatus } from '../enums';
import { type LaborLine, type Sale } from '../entities';
import { summarizeLabor } from './laborReport';

function sale(overrides: Partial<Sale> = {}): Sale {
  return {
    id: 's',
    saleNumber: 'S',
    items: [],
    laborLines: [],
    mechanicId: null,
    mechanicName: null,
    discountType: DiscountType.amount,
    paymentMethod: PaymentMethod.cash,
    tenders: {},
    amountReceived: 0,
    changeGiven: 0,
    status: SaleStatus.completed,
    cashierId: 'c1',
    cashierName: 'Cashier',
    createdAt: new Date('2026-05-30T10:00:00Z'),
    updatedAt: null,
    draftId: null,
    notes: null,
    voidedAt: null,
    voidedBy: null,
    voidedByName: null,
    voidReason: null,
    ...overrides,
  };
}

const labor = (id: string, fee: number): LaborLine => ({
  id,
  description: `Job ${id}`,
  fee,
});

describe('summarizeLabor', () => {
  it('totals labor, counts service sales, and groups by mechanic', () => {
    const report = summarizeLabor([
      sale({ mechanicId: 'm1', mechanicName: 'Juan', laborLines: [labor('a', 150)] }),
      sale({ mechanicId: 'm1', mechanicName: 'Juan', laborLines: [labor('b', 50)] }),
      sale({ mechanicId: 'm2', mechanicName: 'Pedro', laborLines: [labor('c', 300)] }),
    ]);

    expect(report.totalLabor).toBe(500);
    expect(report.serviceSaleCount).toBe(3);
    // Sorted by labor total desc: Pedro (300) then Juan (200).
    expect(report.byMechanic.map((m) => m.mechanicName)).toEqual(['Pedro', 'Juan']);
    const juan = report.byMechanic.find((m) => m.mechanicId === 'm1')!;
    expect(juan.laborTotal).toBe(200);
    expect(juan.jobCount).toBe(2);
  });

  it('excludes voided sales', () => {
    const report = summarizeLabor([
      sale({ mechanicId: 'm1', mechanicName: 'Juan', laborLines: [labor('a', 150)] }),
      sale({
        mechanicId: 'm1',
        mechanicName: 'Juan',
        laborLines: [labor('b', 999)],
        status: SaleStatus.voided,
      }),
    ]);
    expect(report.totalLabor).toBe(150);
    expect(report.serviceSaleCount).toBe(1);
  });

  it('ignores parts-only sales (no labor)', () => {
    const report = summarizeLabor([
      sale({ mechanicId: 'm1', mechanicName: 'Juan', laborLines: [labor('a', 150)] }),
      sale(), // no labor
    ]);
    expect(report.totalLabor).toBe(150);
    expect(report.serviceSaleCount).toBe(1);
    expect(report.byMechanic).toHaveLength(1);
  });

  it('labor without a mechanic collapses into an Unassigned bucket', () => {
    const report = summarizeLabor([
      sale({ laborLines: [labor('a', 100)] }), // no mechanic
      sale({ mechanicId: 'm1', mechanicName: 'Juan', laborLines: [labor('b', 40)] }),
    ]);
    expect(report.totalLabor).toBe(140);
    const unassigned = report.byMechanic.find((m) => m.mechanicId === null)!;
    expect(unassigned.mechanicName).toBe('Unassigned');
    expect(unassigned.laborTotal).toBe(100);
    expect(unassigned.jobCount).toBe(1);
  });

  it('empty input yields an empty report', () => {
    const report = summarizeLabor([]);
    expect(report.totalLabor).toBe(0);
    expect(report.serviceSaleCount).toBe(0);
    expect(report.byMechanic).toEqual([]);
  });
});
