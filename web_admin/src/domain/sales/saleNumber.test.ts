import { describe, expect, it } from 'vitest';
import { counterKey, formatSaleNumber } from './saleNumber';

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
