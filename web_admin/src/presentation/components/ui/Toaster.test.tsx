import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { act, render, screen } from '@testing-library/react';
import { toast } from './toast';
import { Toaster } from './Toaster';

beforeEach(() => vi.useFakeTimers());
afterEach(() => vi.useRealTimers());

describe('Toaster', () => {
  it('shows a success toast with mono detail, then auto-dismisses', () => {
    render(<Toaster />);
    act(() => toast.success('Copied to clipboard', 'SALE-20260831-027'));
    expect(screen.getByRole('status')).toHaveTextContent('Copied to clipboard');
    expect(screen.getByText('SALE-20260831-027')).toBeInTheDocument();
    act(() => vi.advanceTimersByTime(2000));
    expect(screen.queryByRole('status')).not.toBeInTheDocument();
  });

  it('a second toast replaces the first and resets the timer', () => {
    render(<Toaster />);
    act(() => toast.success('Copied to clipboard', 'A'));
    act(() => vi.advanceTimersByTime(1500));
    act(() => toast.success('Copied to clipboard', 'B'));
    act(() => vi.advanceTimersByTime(1500));
    // 3s after the first, but only 1.5s after the second — still visible, showing B.
    expect(screen.getByText('B')).toBeInTheDocument();
    expect(screen.queryByText('A')).not.toBeInTheDocument();
    act(() => vi.advanceTimersByTime(500));
    expect(screen.queryByRole('status')).not.toBeInTheDocument();
  });
});
