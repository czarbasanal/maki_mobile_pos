import { describe, expect, it } from 'vitest';
import { payPeriodFor, shiftPeriod } from './payPeriod';

describe('payPeriodFor', () => {
  it('snaps back to the most recent Monday for weekStartDay=1', () => {
    // 2026-07-22 is a Wednesday
    const p = payPeriodFor(new Date(2026, 6, 22), 1);
    expect(p.start).toBe('2026-07-20');
    expect(p.end).toBe('2026-07-26');
    expect(p.dates).toHaveLength(7);
    expect(p.dates[2]).toBe('2026-07-22');
  });

  it('anchor already on the start day stays put', () => {
    const p = payPeriodFor(new Date(2026, 6, 20), 1); // a Monday
    expect(p.start).toBe('2026-07-20');
  });

  it('handles Sunday start (weekStartDay=7)', () => {
    const p = payPeriodFor(new Date(2026, 6, 22), 7);
    expect(p.start).toBe('2026-07-19');
    expect(p.end).toBe('2026-07-25');
  });

  it('spans a year boundary', () => {
    const p = payPeriodFor(new Date(2026, 0, 1), 1); // Thu 2026-01-01
    expect(p.start).toBe('2025-12-29');
    expect(p.end).toBe('2026-01-04');
  });

  it('shiftPeriod moves whole weeks', () => {
    const p = payPeriodFor(new Date(2026, 6, 22), 1);
    expect(shiftPeriod(p, -1).start).toBe('2026-07-13');
    expect(shiftPeriod(p, 1).start).toBe('2026-07-27');
  });
});
