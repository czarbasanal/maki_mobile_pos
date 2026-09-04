import { beforeEach, describe, expect, it } from 'vitest';
import {
  DEFAULT_SHOP_OFFSET_MINUTES,
  formatShopDateTime,
  DEFAULT_SHOP_TIMEZONE_ID,
  getAmbientShopTimezone,
  instantOf,
  setAmbientShopTimezone,
  shopDateKey,
  shopDayInt,
  shopEndOfDay,
  shopIsoDate,
  shopOffsetMinutes,
  shopStartOfDay,
  shopTimeOf,
  shopWall,
} from './shopTime';
import { SHOP_TIMEZONES, shopTimezoneById } from './shopTimezones';

const PH = 480;
const EST = -300;

describe('shopTimeOf', () => {
  it('shifts an instant into shop wall time (read with getUTC*)', () => {
    const wall = shopTimeOf(new Date(Date.UTC(2026, 7, 26, 15, 30)), PH);
    expect(wall.getUTCFullYear()).toBe(2026);
    expect(wall.getUTCMonth()).toBe(7);
    expect(wall.getUTCDate()).toBe(26);
    expect(wall.getUTCHours()).toBe(23);
  });
});

describe('instantOf', () => {
  it('round-trips with shopTimeOf', () => {
    const instant = new Date(Date.UTC(2026, 7, 26, 15, 30, 45, 123));
    expect(instantOf(shopTimeOf(instant, PH), PH).getTime()).toBe(instant.getTime());
    expect(instantOf(shopTimeOf(instant, EST), EST).getTime()).toBe(instant.getTime());
  });

  it('maps shop midnight to the right instant', () => {
    expect(instantOf(shopWall(2026, 8, 26), PH).toISOString()).toBe('2026-08-25T16:00:00.000Z');
  });
});

describe('shopDayInt', () => {
  it('matches the rules yyyymmdd shape', () => {
    expect(shopDayInt(new Date(Date.UTC(2026, 7, 26, 5, 0)), PH)).toBe(20260826);
  });

  it('crosses the day boundary at shop midnight', () => {
    const instant = new Date(Date.UTC(2026, 7, 25, 16, 0));
    expect(shopDayInt(instant, PH)).toBe(20260826);
    expect(shopDayInt(instant, EST)).toBe(20260825);
  });

  it('handles a year boundary', () => {
    expect(shopDayInt(new Date(Date.UTC(2026, 11, 31, 16, 0)), PH)).toBe(20270101);
  });
});

describe('day bounds', () => {
  it('shopStartOfDay returns the instant of shop midnight', () => {
    const i = new Date(Date.UTC(2026, 7, 26, 5, 0));
    expect(shopStartOfDay(i, PH).toISOString()).toBe('2026-08-25T16:00:00.000Z');
  });

  it('shopEndOfDay returns the last millisecond of the shop day', () => {
    const i = new Date(Date.UTC(2026, 7, 26, 5, 0));
    expect(shopEndOfDay(i, PH).toISOString()).toBe('2026-08-26T15:59:59.999Z');
  });

  it('the bounds span exactly one day', () => {
    const i = new Date(Date.UTC(2026, 7, 26, 5, 0));
    expect(shopEndOfDay(i, PH).getTime() - shopStartOfDay(i, PH).getTime()).toBe(86_400_000 - 1);
  });
});

describe('key formatting', () => {
  it('shopDateKey is zero-padded YYYYMMDD', () => {
    expect(shopDateKey(new Date(Date.UTC(2026, 0, 2, 5, 0)), PH)).toBe('20260102');
  });

  it('shopIsoDate is zero-padded yyyy-MM-dd', () => {
    expect(shopIsoDate(new Date(Date.UTC(2026, 0, 2, 5, 0)), PH)).toBe('2026-01-02');
  });
});

describe('ambient timezone', () => {
  beforeEach(() =>
    setAmbientShopTimezone({
      timezoneId: DEFAULT_SHOP_TIMEZONE_ID,
      offsetMinutes: DEFAULT_SHOP_OFFSET_MINUTES,
    }),
  );

  it('defaults to Asia/Manila', () => {
    expect(shopOffsetMinutes()).toBe(480);
    expect(getAmbientShopTimezone().timezoneId).toBe('Asia/Manila');
  });

  it('is used when no offset is passed', () => {
    setAmbientShopTimezone({ timezoneId: 'Asia/Tokyo', offsetMinutes: 540 });
    expect(shopDayInt(new Date(Date.UTC(2026, 7, 25, 15, 30)))).toBe(20260826);
  });
});

describe('SHOP_TIMEZONES', () => {
  it('contains the default at +480', () => {
    expect(shopTimezoneById(DEFAULT_SHOP_TIMEZONE_ID)?.offsetMinutes).toBe(480);
  });

  it('has unique ids and in-range offsets', () => {
    const ids = new Set(SHOP_TIMEZONES.map((t) => t.id));
    expect(ids.size).toBe(SHOP_TIMEZONES.length);
    for (const tz of SHOP_TIMEZONES) {
      expect(tz.offsetMinutes).toBeGreaterThanOrEqual(-720);
      expect(tz.offsetMinutes).toBeLessThanOrEqual(840);
    }
  });

  it('mirrors the Dart catalog', () => {
    // Keep in lock-step with lib/core/utils/shop_timezones.dart.
    expect(SHOP_TIMEZONES.length).toBe(15);
  });
});

describe('formatShopDateTime', () => {
  it('composes date · time in the shop zone', () => {
    // Earlier tests in this file move the ambient zone — pin it back first.
    setAmbientShopTimezone({
      timezoneId: DEFAULT_SHOP_TIMEZONE_ID,
      offsetMinutes: DEFAULT_SHOP_OFFSET_MINUTES,
    });
    // 08:18Z is 4:18 PM in the default shop zone (Asia/Manila, +8).
    expect(formatShopDateTime(new Date('2026-09-01T08:18:00Z'))).toBe('Sep 1, 2026 · 4:18 PM');
  });
});
