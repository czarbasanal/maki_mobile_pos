import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { act, renderHook } from '@testing-library/react';
import { useShopDay } from './useShopDay';
import { shopDateKey } from '@/domain/time/shopTime';

beforeEach(() => vi.useFakeTimers());
afterEach(() => vi.useRealTimers());

describe('useShopDay', () => {
  it('returns the current shop day and flips when PHT midnight passes', () => {
    // Freeze just before PHT midnight: 15:59:40 UTC == 23:59:40 PHT.
    vi.setSystemTime(new Date(Date.UTC(2026, 8, 1, 15, 59, 40)));
    const { result } = renderHook(() => useShopDay());
    const before = result.current;
    expect(before).toBe(shopDateKey(new Date()));

    // Cross midnight; the 30s interval picks it up.
    act(() => vi.advanceTimersByTime(60_000));
    expect(result.current).not.toBe(before);
    expect(result.current).toBe(shopDateKey(new Date()));
  });
});
