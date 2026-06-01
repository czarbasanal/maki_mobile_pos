import { describe, expect, it } from 'vitest';
import { priceHistoryReason } from './priceHistoryReason';

describe('priceHistoryReason', () => {
  it('returns null when neither moved (within EPS)', () => {
    expect(priceHistoryReason(60, 100, 60, 100)).toBeNull();
    expect(priceHistoryReason(60, 100, 60.005, 100.005)).toBeNull();
  });
  it('detects price-only change', () => {
    expect(priceHistoryReason(60, 100, 60, 120)).toBe('Price update');
  });
  it('detects cost-only change', () => {
    expect(priceHistoryReason(60, 100, 70, 100)).toBe('Cost update');
  });
  it('detects both', () => {
    expect(priceHistoryReason(60, 100, 70, 120)).toBe('Price + cost update');
  });
});
