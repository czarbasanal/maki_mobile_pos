import { afterEach, describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { CopyButton } from './CopyButton';
import { Toaster } from './Toaster';

afterEach(() => vi.restoreAllMocks());

function mockClipboard(impl: (v: string) => Promise<void>) {
  Object.assign(navigator, { clipboard: { writeText: vi.fn(impl) } });
  return navigator.clipboard.writeText as ReturnType<typeof vi.fn>;
}

describe('CopyButton', () => {
  it('copies the value and toasts with it', async () => {
    const write = mockClipboard(() => Promise.resolve());
    render(<><CopyButton value="SALE-20260831-027" label="sale number" /><Toaster /></>);
    await userEvent.click(screen.getByRole('button', { name: 'Copy sale number' }));
    expect(write).toHaveBeenCalledWith('SALE-20260831-027');
    expect(await screen.findByRole('status')).toHaveTextContent('Copied to clipboard');
    expect(screen.getByText('SALE-20260831-027')).toBeInTheDocument();
  });

  it('does not trigger the row click around it', async () => {
    mockClipboard(() => Promise.resolve());
    const rowClick = vi.fn();
    render(<div onClick={rowClick}><CopyButton value="X" label="SKU" /></div>);
    await userEvent.click(screen.getByRole('button', { name: 'Copy SKU' }));
    expect(rowClick).not.toHaveBeenCalled();
  });

  it('survives a clipboard failure (insecure origin) with an error toast', async () => {
    mockClipboard(() => Promise.reject(new Error('denied')));
    render(<><CopyButton value="X" label="SKU" /><Toaster /></>);
    await userEvent.click(screen.getByRole('button', { name: 'Copy SKU' }));
    expect(await screen.findByRole('status')).toHaveTextContent('Copy failed');
  });
});
