import { describe, expect, it } from 'vitest';
import { parseShopTimezone } from './FirestoreShopTimezoneRepository';

describe('parseShopTimezone', () => {
  it('a missing doc reads as the defaults', () => {
    expect(parseShopTimezone(undefined)).toEqual({
      timezoneId: 'Asia/Manila',
      offsetMinutes: 480,
    });
  });

  it('an empty doc reads as the defaults', () => {
    expect(parseShopTimezone({})).toEqual({ timezoneId: 'Asia/Manila', offsetMinutes: 480 });
  });

  it('reads a stored timezone', () => {
    expect(parseShopTimezone({ timezoneId: 'Asia/Tokyo', tzOffsetMinutes: 540 })).toEqual({
      timezoneId: 'Asia/Tokyo',
      offsetMinutes: 540,
    });
  });

  it('ignores unrelated keys in the shared general doc', () => {
    expect(
      parseShopTimezone({ timezoneId: 'UTC', tzOffsetMinutes: 0, other: true }).offsetMinutes,
    ).toBe(0);
  });

  it('falls back on an out-of-range offset', () => {
    expect(parseShopTimezone({ tzOffsetMinutes: 99999 }).offsetMinutes).toBe(480);
  });

  it('falls back on a non-numeric offset', () => {
    expect(parseShopTimezone({ tzOffsetMinutes: 'eight' }).offsetMinutes).toBe(480);
  });

  it('falls back on a non-integer offset', () => {
    expect(parseShopTimezone({ tzOffsetMinutes: 480.5 }).offsetMinutes).toBe(480);
  });
});
