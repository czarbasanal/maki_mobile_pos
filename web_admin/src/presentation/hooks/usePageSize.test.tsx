import { beforeEach, describe, expect, it } from 'vitest';
import { act, renderHook } from '@testing-library/react';
import { PAGE_SIZE_OPTIONS, usePageSize } from './usePageSize';

describe('usePageSize', () => {
  beforeEach(() => localStorage.clear());

  it('offers 25/50/100/500/1000 and starts at 25', () => {
    expect(PAGE_SIZE_OPTIONS).toEqual([25, 50, 100, 500, 1000]);
    const { result } = renderHook(() => usePageSize('inventory'));
    expect(result.current[0]).toBe(25);
  });

  it('remembers the choice for next time', () => {
    const first = renderHook(() => usePageSize('inventory'));
    act(() => first.result.current[1](100));
    expect(first.result.current[0]).toBe(100);

    // A fresh mount (e.g. revisiting the page) picks it back up.
    const second = renderHook(() => usePageSize('inventory'));
    expect(second.result.current[0]).toBe(100);
  });

  it('keeps each table independent', () => {
    const inventory = renderHook(() => usePageSize('inventory'));
    act(() => inventory.result.current[1](500));

    const sales = renderHook(() => usePageSize('sales'));
    expect(sales.result.current[0]).toBe(25);
    expect(renderHook(() => usePageSize('inventory')).result.current[0]).toBe(500);
  });

  it('falls back to 25 when the stored value is junk or not an offered size', () => {
    localStorage.setItem('maki.pageSize.inventory', 'banana');
    expect(renderHook(() => usePageSize('inventory')).result.current[0]).toBe(25);

    localStorage.setItem('maki.pageSize.inventory', '37');
    expect(renderHook(() => usePageSize('inventory')).result.current[0]).toBe(25);
  });

  it('ignores an attempt to set a size that isn\'t offered', () => {
    const { result } = renderHook(() => usePageSize('inventory'));
    act(() => result.current[1](37 as never));
    expect(result.current[0]).toBe(25);
  });
});
