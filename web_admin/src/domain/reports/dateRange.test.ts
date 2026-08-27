import { describe, expect, it } from 'vitest';
import { instantOf, shopTimeOf, shopWall } from '@/domain/time/shopTime';
import { resolvePreset } from './dateRange';

const PH_OFFSET = 480;

// Fixed "now": Wed 2026-05-13 14:30 SHOP time, as the instant it really is.
const now = instantOf(shopWall(2026, 5, 13, 14, 30), PH_OFFSET);

// The bounds come back as instants; read them through the shop clock.
function iso(d: Date) {
  const w = shopTimeOf(d, PH_OFFSET);
  return `${w.getUTCFullYear()}-${String(w.getUTCMonth() + 1).padStart(2, '0')}-${String(
    w.getUTCDate(),
  ).padStart(2, '0')} ${String(w.getUTCHours()).padStart(2, '0')}:${String(
    w.getUTCMinutes(),
  ).padStart(2, '0')}`;
}

describe('resolvePreset', () => {
  it('today = start..end of the same day', () => {
    const r = resolvePreset('today', now, PH_OFFSET);
    expect(iso(r.start)).toBe('2026-05-13 00:00');
    expect(iso(r.end)).toBe('2026-05-13 23:59');
  });

  it('yesterday = the previous day', () => {
    const r = resolvePreset('yesterday', now, PH_OFFSET);
    expect(iso(r.start)).toBe('2026-05-12 00:00');
    expect(iso(r.end)).toBe('2026-05-12 23:59');
  });

  it('last7 = 7 days inclusive of today', () => {
    const r = resolvePreset('last7', now, PH_OFFSET);
    expect(iso(r.start)).toBe('2026-05-07 00:00'); // 6 days back
    expect(iso(r.end)).toBe('2026-05-13 23:59');
  });

  it('last30 = 30 days inclusive of today', () => {
    const r = resolvePreset('last30', now, PH_OFFSET);
    expect(iso(r.start)).toBe('2026-04-14 00:00'); // 29 days back
    expect(iso(r.end)).toBe('2026-05-13 23:59');
  });

  it('thisMonth = 1st of month..now-day end', () => {
    const r = resolvePreset('thisMonth', now, PH_OFFSET);
    expect(iso(r.start)).toBe('2026-05-01 00:00');
    expect(iso(r.end)).toBe('2026-05-13 23:59');
  });
});

describe('resolvePreset in shop time', () => {
  const PH = 480;

  it('today spans the shop day as instants', () => {
    const r = resolvePreset('today', new Date(Date.UTC(2026, 7, 26, 5, 0)), PH);
    expect(r.start.toISOString()).toBe('2026-08-25T16:00:00.000Z');
    expect(r.end.toISOString()).toBe('2026-08-26T15:59:59.999Z');
  });

  it('yesterday spans the previous shop day', () => {
    const r = resolvePreset('yesterday', new Date(Date.UTC(2026, 7, 26, 5, 0)), PH);
    expect(r.start.toISOString()).toBe('2026-08-24T16:00:00.000Z');
    expect(r.end.toISOString()).toBe('2026-08-25T15:59:59.999Z');
  });

  it('last7 covers seven shop days inclusive', () => {
    const r = resolvePreset('last7', new Date(Date.UTC(2026, 7, 26, 5, 0)), PH);
    expect(r.start.toISOString()).toBe('2026-08-19T16:00:00.000Z');
    expect(r.end.getTime() - r.start.getTime()).toBe(7 * 86_400_000 - 1);
  });

  it('last30 covers thirty shop days inclusive', () => {
    const r = resolvePreset('last30', new Date(Date.UTC(2026, 7, 26, 5, 0)), PH);
    expect(r.end.getTime() - r.start.getTime()).toBe(30 * 86_400_000 - 1);
  });

  it('thisMonth starts at shop midnight on the 1st', () => {
    const r = resolvePreset('thisMonth', new Date(Date.UTC(2026, 7, 26, 5, 0)), PH);
    expect(r.start.toISOString()).toBe('2026-07-31T16:00:00.000Z');
  });

  it('an instant just after shop midnight belongs to the new day', () => {
    const r = resolvePreset('today', new Date(Date.UTC(2026, 7, 25, 16, 1)), PH);
    expect(r.start.toISOString()).toBe('2026-08-25T16:00:00.000Z');
  });
});
