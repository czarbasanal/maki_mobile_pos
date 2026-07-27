import { describe, expect, it } from 'vitest';
import { jobOrderPrefixFor, nextJobOrderNumber } from './joNumber';

const jul23 = new Date(2026, 6, 23, 14, 30);

describe('jobOrderPrefixFor', () => {
  it('formats as JO-MMDDYY-', () => {
    expect(jobOrderPrefixFor(jul23)).toBe('JO-072326-');
    expect(jobOrderPrefixFor(new Date(2027, 0, 5))).toBe('JO-010527-');
  });
});

describe('nextJobOrderNumber', () => {
  it('starts at 001 when no job orders exist for the day', () => {
    expect(nextJobOrderNumber(jul23, [])).toBe('JO-072326-001');
  });

  it('increments past the highest sequence for today', () => {
    expect(
      nextJobOrderNumber(jul23, [
        'JO-072326-001',
        'JO-072326-003', // gap: 002 was deleted — never reuse
        'Juan / ABC-123', // legacy customer/plate names ignored
        'JO-072226-009', // yesterday's numbering ignored
      ]),
    ).toBe('JO-072326-004');
  });

  it('grows past 999 without truncating', () => {
    expect(nextJobOrderNumber(jul23, ['JO-072326-999'])).toBe('JO-072326-1000');
  });

  it("ignores malformed suffixes on today's prefix", () => {
    expect(nextJobOrderNumber(jul23, ['JO-072326-abc', 'JO-072326-'])).toBe('JO-072326-001');
  });
});
