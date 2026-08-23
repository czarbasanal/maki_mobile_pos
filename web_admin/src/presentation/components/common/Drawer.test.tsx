// Slide-over panel used for the product view. Same interaction contract as
// Dialog (portal, ESC, click-outside) but anchored to the right edge and sized
// for reading a record rather than filling a form.
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Drawer } from './Drawer';

describe('Drawer', () => {
  it('renders its content when open', () => {
    render(
      <Drawer open onClose={() => {}} title="Brake shoe">
        <p>Quantity 8</p>
      </Drawer>,
    );

    expect(screen.getByRole('dialog', { name: 'Brake shoe' })).toBeInTheDocument();
    expect(screen.getByText('Quantity 8')).toBeInTheDocument();
  });

  it('renders nothing when closed', () => {
    render(
      <Drawer open={false} onClose={() => {}} title="Brake shoe">
        <p>Quantity 8</p>
      </Drawer>,
    );

    expect(screen.queryByRole('dialog')).toBeNull();
    expect(screen.queryByText('Quantity 8')).toBeNull();
  });

  it('closes on Escape', async () => {
    const onClose = vi.fn();
    render(<Drawer open onClose={onClose} title="Brake shoe">body</Drawer>);

    await userEvent.keyboard('{Escape}');

    expect(onClose).toHaveBeenCalledTimes(1);
  });

  it('closes when the backdrop is clicked', async () => {
    const onClose = vi.fn();
    render(<Drawer open onClose={onClose} title="Brake shoe">body</Drawer>);

    await userEvent.click(screen.getByTestId('drawer-backdrop'));

    expect(onClose).toHaveBeenCalledTimes(1);
  });

  it('stays open when the panel itself is clicked', async () => {
    const onClose = vi.fn();
    render(<Drawer open onClose={onClose} title="Brake shoe">body</Drawer>);

    await userEvent.click(screen.getByText('body'));

    expect(onClose).not.toHaveBeenCalled();
  });

  it('closes from the close button', async () => {
    const onClose = vi.fn();
    render(<Drawer open onClose={onClose} title="Brake shoe">body</Drawer>);

    await userEvent.click(screen.getByRole('button', { name: 'Close' }));

    expect(onClose).toHaveBeenCalledTimes(1);
  });

  it('ignores Escape and the backdrop while a write is in flight', async () => {
    // dismissable=false is how callers stop a stray click discarding a
    // half-finished mutation, matching Dialog's contract.
    const onClose = vi.fn();
    render(
      <Drawer open onClose={onClose} title="Brake shoe" dismissable={false}>
        body
      </Drawer>,
    );

    await userEvent.keyboard('{Escape}');
    await userEvent.click(screen.getByTestId('drawer-backdrop'));

    expect(onClose).not.toHaveBeenCalled();
  });
});
