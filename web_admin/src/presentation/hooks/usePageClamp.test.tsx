import { describe, expect, it, vi } from 'vitest';
import { renderHook } from '@testing-library/react';
import { usePageClamp } from './usePageClamp';

describe('usePageClamp', () => {
  it('snaps back to the last non-empty page when the list shrinks under a parked page', () => {
    const setPage = vi.fn();
    const { rerender } = renderHook(
      ({ page, total }) => usePageClamp(page, setPage, total, 25),
      { initialProps: { page: 2, total: 26 } },
    );
    expect(setPage).not.toHaveBeenCalled();

    rerender({ page: 2, total: 25 });
    expect(setPage).toHaveBeenCalledWith(1);
  });

  it('clamps to the new last page, not always page 1', () => {
    const setPage = vi.fn();
    const { rerender } = renderHook(
      ({ page, total }) => usePageClamp(page, setPage, total, 25),
      { initialProps: { page: 3, total: 51 } },
    );
    expect(setPage).not.toHaveBeenCalled();

    rerender({ page: 3, total: 50 });
    expect(setPage).toHaveBeenCalledWith(2);
  });

  it('does nothing while the page is still within range', () => {
    const setPage = vi.fn();
    const { rerender } = renderHook(
      ({ page, total }) => usePageClamp(page, setPage, total, 25),
      { initialProps: { page: 2, total: 60 } },
    );
    rerender({ page: 2, total: 30 });
    expect(setPage).not.toHaveBeenCalled();
  });

  it('treats an empty list as one page', () => {
    const setPage = vi.fn();
    renderHook(({ page, total }) => usePageClamp(page, setPage, total, 25), {
      initialProps: { page: 2, total: 0 },
    });
    expect(setPage).toHaveBeenCalledWith(1);
  });
});
