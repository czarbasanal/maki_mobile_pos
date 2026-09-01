import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { EmptyState } from './EmptyState';
import { ErrorState } from './ErrorState';
import { Skeleton } from './Skeleton';

describe('ui states', () => {
  it('EmptyState shows message and optional action', () => {
    render(<EmptyState message="No sales yet" action={<button>New sale</button>} />);
    expect(screen.getByText('No sales yet')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'New sale' })).toBeInTheDocument();
  });
  it('ErrorState wires Retry', async () => {
    const onRetry = vi.fn();
    render(<ErrorState message="Load failed" onRetry={onRetry} />);
    await userEvent.click(screen.getByRole('button', { name: 'Retry' }));
    expect(onRetry).toHaveBeenCalledOnce();
  });
  it('Skeleton takes explicit dimensions', () => {
    const { container } = render(<Skeleton width="120px" height="23px" />);
    const el = container.firstElementChild as HTMLElement;
    expect(el.style.width).toBe('120px');
    expect(el.style.height).toBe('23px');
  });
});
