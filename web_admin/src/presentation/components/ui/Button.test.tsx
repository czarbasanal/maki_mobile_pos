import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Button } from './Button';
import { IconButton } from './IconButton';

describe('Button', () => {
  it('fires onClick', async () => {
    const onClick = vi.fn();
    render(<Button variant="primary" onClick={onClick}>New sale</Button>);
    await userEvent.click(screen.getByRole('button', { name: 'New sale' }));
    expect(onClick).toHaveBeenCalledOnce();
  });

  it('is disabled while loading and shows no icon slot content', () => {
    render(<Button loading icon={<svg data-testid="icon" />}>Save</Button>);
    const btn = screen.getByRole('button');
    expect(btn).toBeDisabled();
    expect(screen.queryByTestId('icon')).not.toBeInTheDocument();
  });

  it('disabled blocks clicks', async () => {
    const onClick = vi.fn();
    render(<Button disabled onClick={onClick}>Save</Button>);
    await userEvent.click(screen.getByRole('button')).catch(() => {});
    expect(onClick).not.toHaveBeenCalled();
  });
});

describe('IconButton', () => {
  it('always exposes its title as accessible name', () => {
    render(<IconButton title="Copy sale number"><svg /></IconButton>);
    expect(screen.getByRole('button', { name: 'Copy sale number' })).toHaveAttribute('title', 'Copy sale number');
  });
});
