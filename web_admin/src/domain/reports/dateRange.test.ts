import { describe, expect, it } from 'vitest';
import { resolvePreset } from './dateRange';

// Fixed "now": Wed 2026-05-13 14:30 local.
const now = new Date(2026, 4, 13, 14, 30, 0);

function iso(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(
    d.getDate(),
  ).padStart(2, '0')} ${String(d.getHours()).padStart(2, '0')}:${String(
    d.getMinutes(),
  ).padStart(2, '0')}`;
}

describe('resolvePreset', () => {
  it('today = start..end of the same day', () => {
    const r = resolvePreset('today', now);
    expect(iso(r.start)).toBe('2026-05-13 00:00');
    expect(iso(r.end)).toBe('2026-05-13 23:59');
  });

  it('yesterday = the previous day', () => {
    const r = resolvePreset('yesterday', now);
    expect(iso(r.start)).toBe('2026-05-12 00:00');
    expect(iso(r.end)).toBe('2026-05-12 23:59');
  });

  it('last7 = 7 days inclusive of today', () => {
    const r = resolvePreset('last7', now);
    expect(iso(r.start)).toBe('2026-05-07 00:00'); // 6 days back
    expect(iso(r.end)).toBe('2026-05-13 23:59');
  });

  it('last30 = 30 days inclusive of today', () => {
    const r = resolvePreset('last30', now);
    expect(iso(r.start)).toBe('2026-04-14 00:00'); // 29 days back
    expect(iso(r.end)).toBe('2026-05-13 23:59');
  });

  it('thisMonth = 1st of month..now-day end', () => {
    const r = resolvePreset('thisMonth', now);
    expect(iso(r.start)).toBe('2026-05-01 00:00');
    expect(iso(r.end)).toBe('2026-05-13 23:59');
  });
});
