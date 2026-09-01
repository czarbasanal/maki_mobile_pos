import { describe, expect, it } from 'vitest';
import { businessDayFor, formatDayInt, isRegisterOpen } from './DrawerState';
import { instantOf } from '../time/shopTime';

describe('isRegisterOpen', () => {
  it('open when sales exist past the last close', () => {
    expect(isRegisterOpen({ lastSaleDay: 20260831, lastClosedDay: 20260830 })).toBe(true);
    expect(isRegisterOpen({ lastSaleDay: 20260831, lastClosedDay: null })).toBe(true);
  });
  it('closed when the day is sealed or nothing was ever sold', () => {
    expect(isRegisterOpen({ lastSaleDay: 20260831, lastClosedDay: 20260831 })).toBe(false);
    expect(isRegisterOpen({ lastSaleDay: null, lastClosedDay: null })).toBe(false);
  });
});

describe('businessDayFor', () => {
  const pastMidnight = instantOf(new Date(Date.UTC(2026, 8, 1, 0, 30))); // Sep 1, 00:30 shop wall
  it('an open shift past midnight still reports its opening day', () => {
    expect(businessDayFor({ lastSaleDay: 20260831, lastClosedDay: 20260830 }, pastMidnight)).toBe(20260831);
  });
  it('falls back to the shop calendar day otherwise', () => {
    expect(businessDayFor({ lastSaleDay: 20260831, lastClosedDay: 20260831 }, pastMidnight)).toBe(20260901);
    expect(businessDayFor(null, pastMidnight)).toBe(20260901);
  });
});

describe('formatDayInt', () => {
  it('renders "dddd, MMM D, YYYY"', () => {
    expect(formatDayInt(20260831)).toBe('Monday, Aug 31, 2026');
  });
});
