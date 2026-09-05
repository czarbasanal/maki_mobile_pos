// The recovery action must actually WIDEN (review finding): a page already
// on 7 days offers 30 days, and 30 days offers nothing. The note must
// describe the range the figures are really scoped to, not an unapplied
// Custom pill.
import { describe, expect, it } from 'vitest';
import { act, renderHook } from '@testing-library/react';
import { useReportRange } from './useReportRange';

describe('useReportRange', () => {
  it('widens one step: today → 7 days → 30 days → nothing', () => {
    const { result } = renderHook(() => useReportRange('today'));
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
    const { result } = renderHook(() => useReportRange('today', true));
    expect(result.current.widen).toBeNull();
  });

  it('an unapplied Custom pill keeps the default range AND the default note', () => {
    const { result } = renderHook(() => useReportRange('last7'));
    act(() => result.current.setPreset('custom'));
    expect(result.current.rangeNote).toBe('in the last 7 days');
    act(() => {
      result.current.setCustomStart('2026-08-01');
      result.current.setCustomEnd('2026-08-03');
    });
    expect(result.current.rangeNote).toBe('in the selected range');
  });
});
