// paidVia round-trip — the mandatory carry-forward from the task-6 review
// finding: the web Expense entity/converter previously dropped paidVia
// entirely, so a web-created expense would silently read back as 'cash' on
// mobile. Reads must default a missing/unknown value to 'cash' (mirrors
// PaymentMethod.fromString's orElse); writes must always include it.
import { describe, expect, it } from 'vitest';
import { Timestamp } from 'firebase/firestore';
import type { Expense } from '@/domain/entities';
import { expenseConverter } from './expenseConverter';

// Minimal fake snapshot — the converter only reads `.id` and `.data()`.
const snap = (id: string, data: Record<string, unknown>) =>
  ({ id, data: () => data }) as never;

const baseDoc = (overrides: Record<string, unknown> = {}) => {
  const created = Timestamp.fromDate(new Date('2026-07-10T00:00:00.000Z'));
  return {
    description: 'Fuel',
    amount: 500,
    category: 'Transportation',
    date: created,
    createdAt: created,
    ...overrides,
  };
};

describe('expenseConverter.fromFirestore — paidVia', () => {
  it('reads a stored paidVia value', () => {
    const e = expenseConverter.fromFirestore(snap('e1', baseDoc({ paidVia: 'gcash' })));
    expect(e.paidVia).toBe('gcash');
  });

  it('defaults to cash when the field is missing (legacy docs)', () => {
    const e = expenseConverter.fromFirestore(snap('e2', baseDoc()));
    expect(e.paidVia).toBe('cash');
  });

  it('defaults to cash for an unknown/corrupt stored value', () => {
    const e = expenseConverter.fromFirestore(snap('e3', baseDoc({ paidVia: 'bogus' })));
    expect(e.paidVia).toBe('cash');
  });
});

describe('expenseConverter.toFirestore — paidVia', () => {
  it('always writes paidVia', () => {
    const expense: Expense = {
      id: 'e1',
      description: 'Fuel',
      amount: 500,
      category: 'Transportation',
      date: new Date('2026-07-10T00:00:00.000Z'),
      paidVia: 'gcash',
      notes: null,
      receiptNumber: null,
      receiptImageUrl: null,
      createdAt: new Date('2026-07-10T00:00:00.000Z'),
      updatedAt: null,
      createdBy: 'u1',
      createdByName: 'Cashier',
      updatedBy: null,
      updatedByName: null,
    };
    const data = expenseConverter.toFirestore(expense as never);
    expect(data.paidVia).toBe('gcash');
  });
});

// updatedByName — Record history's "who last touched this" (Expenses redesign
// §4: two-mode modal panel). Read defaults to null (undefined/legacy docs);
// write always carries it, mirroring updatedBy.
describe('expenseConverter.fromFirestore — updatedByName', () => {
  it('reads a stored updatedByName value', () => {
    const e = expenseConverter.fromFirestore(snap('e1', baseDoc({ updatedByName: 'Czar' })));
    expect(e.updatedByName).toBe('Czar');
  });

  it('defaults to null when missing (never edited, or a legacy doc)', () => {
    const e = expenseConverter.fromFirestore(snap('e2', baseDoc()));
    expect(e.updatedByName).toBeNull();
  });
});

describe('expenseConverter.toFirestore — updatedByName', () => {
  it('always writes updatedByName', () => {
    const expense: Expense = {
      id: 'e1',
      description: 'Fuel',
      amount: 500,
      category: 'Transportation',
      date: new Date('2026-07-10T00:00:00.000Z'),
      paidVia: 'gcash',
      notes: null,
      receiptNumber: null,
      receiptImageUrl: null,
      createdAt: new Date('2026-07-10T00:00:00.000Z'),
      updatedAt: new Date('2026-07-12T00:00:00.000Z'),
      createdBy: 'u1',
      createdByName: 'Cashier',
      updatedBy: 'u2',
      updatedByName: 'Czar',
    };
    const data = expenseConverter.toFirestore(expense as never);
    expect(data.updatedByName).toBe('Czar');
  });
});
