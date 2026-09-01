import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { act, fireEvent, render, screen } from '@testing-library/react';
import { SearchInput } from './SearchInput';

beforeEach(() => vi.useFakeTimers());
afterEach(() => vi.useRealTimers());

describe('SearchInput', () => {
  it('debounces onChange by 250ms', () => {
    const onChange = vi.fn();
    render(<SearchInput value="" onChange={onChange} placeholder="Search sale no." />);
    fireEvent.change(screen.getByPlaceholderText('Search sale no.'), { target: { value: 'SALE' } });
    expect(onChange).not.toHaveBeenCalled();
    act(() => vi.advanceTimersByTime(250));
    expect(onChange).toHaveBeenCalledWith('SALE');
  });

  it('clear emits empty immediately', () => {
    const onChange = vi.fn();
    render(<SearchInput value="SALE" onChange={onChange} />);
    fireEvent.click(screen.getByRole('button', { name: 'Clear search' }));
    expect(onChange).toHaveBeenCalledWith('');
  });

  it('cancels pending debounce when value prop changes externally', () => {
    const onChange = vi.fn();
    const { rerender } = render(<SearchInput value="" onChange={onChange} />);
    fireEvent.change(screen.getByPlaceholderText('Search'), { target: { value: 'STALE' } });
    expect(onChange).not.toHaveBeenCalled();
    rerender(<SearchInput value="EXTERNAL" onChange={onChange} />);
    act(() => vi.advanceTimersByTime(250));
    expect(onChange).not.toHaveBeenCalledWith('STALE');
  });
});

describe('hero variant (POS register)', () => {
  it('forwards keydown and exposes the input ref for programmatic focus', () => {
    const onKeyDown = vi.fn();
    const ref = { current: null as HTMLInputElement | null };
    render(
      <SearchInput value="" onChange={vi.fn()} variant="hero" onKeyDown={onKeyDown} inputRef={ref} placeholder="Scan" />,
    );
    const input = screen.getByPlaceholderText('Scan');
    fireEvent.keyDown(input, { key: 'Enter' });
    expect(onKeyDown).toHaveBeenCalled();
    expect(ref.current).toBe(input);
    ref.current?.focus();
    expect(input).toHaveFocus();
  });
});
