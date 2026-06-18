import { describe, expect, it } from 'vitest';
import { DiscountType, PaymentMethod, SaleStatus } from '../../domain/enums';
import { type Sale } from '../../domain/entities';
import { parseCsv, salesToCsv, toCsv } from './csv';

function sale(overrides: Partial<Sale> = {}): Sale {
  return {
    id: 's1',
    saleNumber: 'OR-0001',
    items: [
      {
        id: 'i1',
        productId: 'p1',
        sku: 'SKU-1',
        name: 'Spark Plug',
        unitPrice: 100,
        unitCost: 60,
        quantity: 2,
        discountValue: 0,
        unit: 'pcs',
      },
    ],
    laborLines: [{ id: 'l1', description: 'Tune-up', fee: 450 }],
    mechanicId: 'm1',
    mechanicName: 'Juan Dela Cruz',
    discountType: DiscountType.amount,
    paymentMethod: PaymentMethod.cash,
    tenders: {},
    amountReceived: 650,
    changeGiven: 0,
    status: SaleStatus.completed,
    cashierId: 'c1',
    cashierName: 'Cashier, A.', // comma -> must be quoted
    createdAt: new Date('2026-05-13T10:00:00Z'),
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

describe('salesToCsv', () => {
  it('emits a header + one row per sale', () => {
    const csv = salesToCsv([sale()]);
    const lines = csv.trim().split('\n');
    expect(lines).toHaveLength(2);
    expect(lines[0]).toBe(
      'saleNumber,date,items,paymentMethod,grossSales,discount,labor,total,cashier,mechanic',
    );
  });

  it('computes the money columns and quotes fields with commas', () => {
    const row = salesToCsv([sale()]).trim().split('\n')[1];
    // gross 200, discount 0, labor 450, total 650
    expect(row).toContain('OR-0001');
    expect(row).toContain('200');
    expect(row).toContain('450');
    expect(row).toContain('650');
    expect(row).toContain('"Cashier, A."'); // quoted because of the comma
    expect(row).toContain('Juan Dela Cruz');
  });

  it('handles empty input (header only)', () => {
    expect(salesToCsv([]).trim().split('\n')).toHaveLength(1);
  });
});

describe('parseCsv', () => {
  it('parses simple rows', () => {
    expect(parseCsv('a,b,c\n1,2,3')).toEqual([
      ['a', 'b', 'c'],
      ['1', '2', '3'],
    ]);
  });

  it('keeps commas inside quoted fields', () => {
    expect(parseCsv('name,note\n"Smith, J",ok')).toEqual([
      ['name', 'note'],
      ['Smith, J', 'ok'],
    ]);
  });

  it('keeps newlines inside quoted fields', () => {
    expect(parseCsv('a\n"x\ny"')).toEqual([['a'], ['x\ny']]);
  });

  it('unescapes doubled quotes', () => {
    expect(parseCsv('a\n"He said ""hi"""')).toEqual([['a'], ['He said "hi"']]);
  });

  it('handles CRLF and a trailing newline', () => {
    expect(parseCsv('a,b\r\n1,2\r\n')).toEqual([
      ['a', 'b'],
      ['1', '2'],
    ]);
  });

  it('strips a leading BOM', () => {
    expect(parseCsv('﻿a\n1')).toEqual([['a'], ['1']]);
  });

  it('returns [] for empty input', () => {
    expect(parseCsv('')).toEqual([]);
  });
});

describe('toCsv', () => {
  it('joins headers + rows and escapes commas, quotes, newlines', () => {
    const out = toCsv(['name', 'qty'], [['Bangus, 1kg', 3], ['He said "hi"', 1]]);
    expect(out).toBe('name,qty\n"Bangus, 1kg",3\n"He said ""hi""",1');
  });
});
