import { describe, expect, it } from 'vitest';
import { counterKey, formatSaleNumber } from './saleNumber';
import { phDayInt } from '@/core/utils/businessDay';

describe('counterKey', () => {
  it('formats local YYYYMMDD, zero-padded', () => {
    expect(counterKey(new Date(2026, 0, 5))).toBe('20260105');
    expect(counterKey(new Date(2026, 11, 31))).toBe('20261231');
  });
});

describe('formatSaleNumber', () => {
  it('pads the sequence to at least 3 digits', () => {
    expect(formatSaleNumber(new Date(2026, 5, 20), 1)).toBe('SALE-20260620-001');
    expect(formatSaleNumber(new Date(2026, 5, 20), 42)).toBe('SALE-20260620-042');
    expect(formatSaleNumber(new Date(2026, 5, 20), 1234)).toBe('SALE-20260620-1234');
  });
});

describe('counterKey in shop time', () => {
  const PH = 480;

  it('uses the shop day, not the browser day', () => {
    // 16:30 UTC Aug 25 is 00:30 Aug 26 in PH.
    expect(counterKey(new Date(Date.UTC(2026, 7, 25, 16, 30)), PH)).toBe('20260826');
  });

  it('agrees with phDayInt for the same instant — same sale transaction', () => {
    const i = new Date(Date.UTC(2026, 7, 25, 16, 30));
    expect(counterKey(i, PH)).toBe(`${phDayInt(i, PH)}`);
  });

  it('formatSaleNumber uses the shop day', () => {
    expect(formatSaleNumber(new Date(Date.UTC(2026, 7, 25, 16, 30)), 7, PH)).toBe(
      'SALE-20260826-007',
    );
  });
});
