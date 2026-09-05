// The recovery action must actually WIDEN (review finding): a page already
// on 7 days offers 30 days, and 30 days offers nothing. The note must
// describe the range the figures are really scoped to, not an unapplied
// Custom pill.
import type { ReactNode } from 'react';
import { describe, expect, it } from 'vitest';
import { act, renderHook } from '@testing-library/react';
import { MemoryRouter, useLocation } from 'react-router-dom';
import { useReportRange } from '@/presentation/hooks/useReportRange';

const wrap = (entry = '/reports/sales') =>
  function Wrapper({ children }: { children: ReactNode }) {
    return <MemoryRouter initialEntries={[entry]}>{children}</MemoryRouter>;
  };
const renderRange = (entry: string, ...args: Parameters<typeof useReportRange>) =>
  renderHook(() => ({ range: useReportRange(...args), search: useLocation().search }), { wrapper: wrap(entry) });

describe('useReportRange — the range rides in the URL so index → report → back keep it', () => {
  it('seeds the preset from ?range=', () => {
    const { result } = renderRange('/reports/sales?range=last30', 'today');
    expect(result.current.range.preset).toBe('last30');
  });

  it('seeds a custom range from ?range=custom&from=&to=', () => {
    const { result } = renderRange('/reports/sales?range=custom&from=2026-08-01&to=2026-08-03', 'today');
    expect(result.current.range.preset).toBe('custom');
    expect(result.current.range.customStart).toBe('2026-08-01');
    expect(result.current.range.customEnd).toBe('2026-08-03');
    expect(result.current.range.rangeNote).toBe('in the selected range');
  });

  it('ignores junk and falls back to the default', () => {
    const { result } = renderRange('/reports/sales?range=bogus&from=x', 'last7');
    expect(result.current.range.preset).toBe('last7');
  });

  it('writes the preset back to the URL (replace, so Back still leaves the report)', () => {
    const { result } = renderRange('/reports/sales', 'today');
    act(() => result.current.range.setPreset('last30'));
    expect(result.current.search).toBe('?range=last30');
    act(() => {
      result.current.range.setPreset('custom');
      result.current.range.setCustomStart('2026-08-01');
      result.current.range.setCustomEnd('2026-08-03');
    });
    expect(result.current.search).toBe('?range=custom&from=2026-08-01&to=2026-08-03');
  });

  it('daily-only roles ignore the URL and stay on today', () => {
    const { result } = renderRange('/reports/sales?range=last30', 'today', true);
    expect(result.current.range.rangeNote).toBe('today');
    const span = result.current.range.effectiveRange.end.getTime() - result.current.range.effectiveRange.start.getTime();
    expect(span).toBeLessThan(24 * 60 * 60 * 1000);
  });
});

describe('useReportRange', () => {
  it('widens one step: today → 7 days → 30 days → nothing', () => {
    const { result } = renderHook(() => useReportRange('today'), { wrapper: wrap() });
    expect(result.current.widenLabel).toBe('Show last 7 days');
    act(() => result.current.widen!());
    expect(result.current.preset).toBe('last7');
    expect(result.current.widenLabel).toBe('Show last 30 days');
    act(() => result.current.widen!());
    expect(result.current.preset).toBe('last30');
    expect(result.current.widen).toBeNull();
    expect(result.current.widenLabel).toBeNull();
  });

  it('daily-only roles get no widen action at all', () => {
    const { result } = renderHook(() => useReportRange('today', true), { wrapper: wrap() });
    expect(result.current.widen).toBeNull();
  });

  it('an unapplied Custom pill keeps the default range AND the default note', () => {
    const { result } = renderHook(() => useReportRange('last7'), { wrapper: wrap() });
    act(() => result.current.setPreset('custom'));
    expect(result.current.rangeNote).toBe('in the last 7 days');
    act(() => {
      result.current.setCustomStart('2026-08-01');
      result.current.setCustomEnd('2026-08-03');
    });
    expect(result.current.rangeNote).toBe('in the selected range');
  });
});
