import { describe, expect, it } from 'vitest';
import { phDayInt } from './businessDay';

describe('phDayInt', () => {
  it('returns the PH (UTC+8) calendar day as a yyyymmdd int for a plain UTC time', () => {
    // 02:00 UTC == 10:00 PH — same calendar day, no crossing.
    expect(phDayInt(new Date('2026-07-25T02:00:00Z'))).toBe(20260725);
  });

  it('rolls over to the next PH day when UTC time is late enough to cross the date line', () => {
    // 17:00 UTC == 01:00 PH the next day.
    expect(phDayInt(new Date('2026-07-25T17:00:00Z'))).toBe(20260726);
  });

  it('rolls over the year boundary correctly (Dec 31 UTC evening -> Jan 1 PH)', () => {
    expect(phDayInt(new Date('2026-12-31T17:00:00Z'))).toBe(20270101);
  });

  it('defaults to the current time when no argument is given', () => {
    const before = phDayInt();
    expect(before).toBeGreaterThan(0);
    expect(Number.isInteger(before)).toBe(true);
  });
});
