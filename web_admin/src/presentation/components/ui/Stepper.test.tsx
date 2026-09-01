import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Stepper } from './Stepper';
import { Chip } from './Chip';

describe('Stepper', () => {
  it('steps up and down and floors at min', async () => {
    const onChange = vi.fn();
    render(<Stepper value={2} onChange={onChange} label="Quantity of Plug" />);
    await userEvent.click(screen.getByRole('button', { name: /increase/i }));
    expect(onChange).toHaveBeenCalledWith(3);
    await userEvent.click(screen.getByRole('button', { name: /decrease/i }));
    expect(onChange).toHaveBeenCalledWith(1);
  });
  it('disables decrease at the floor', () => {
    render(<Stepper value={1} onChange={vi.fn()} label="Quantity" />);
    expect(screen.getByRole('button', { name: /decrease/i })).toBeDisabled();
  });
});

describe('Chip', () => {
  it('reflects active state and fires onClick', async () => {
    const onClick = vi.fn();
    render(<Chip active onClick={onClick}>Berto</Chip>);
    const chip = screen.getByRole('button', { name: 'Berto' });
    expect(chip).toHaveAttribute('aria-pressed', 'true');
    await userEvent.click(chip);
    expect(onClick).toHaveBeenCalledOnce();
  });
});
