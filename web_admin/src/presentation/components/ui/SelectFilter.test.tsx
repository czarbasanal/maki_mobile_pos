import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { SelectFilter } from './SelectFilter';

const options = [
  { value: 'm1', label: 'Jeric', count: 4 },
  { value: 'm2', label: 'Nonoy', count: 2 },
];

function harness(value = '', onChange = vi.fn()) {
  render(
    <div>
      <SelectFilter
        label="Mechanic"
        value={value}
        options={options}
        onChange={onChange}
        allLabel="All mechanics"
      />
      <button type="button">outside</button>
    </div>,
  );
  return onChange;
}

describe('SelectFilter', () => {
  it('opens on the trigger and picks an option (menu closes, onChange fires)', async () => {
    const onChange = harness();
    await userEvent.click(screen.getByRole('button', { name: /Mechanic/ }));
    expect(screen.getByRole('listbox')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('option', { name: /Jeric/ }));
    expect(onChange).toHaveBeenCalledWith('m1');
    expect(screen.queryByRole('listbox')).not.toBeInTheDocument();
  });

  it('shows counts and marks the selected option', async () => {
    harness('m1');
    await userEvent.click(screen.getByRole('button', { name: /Mechanic/ }));
    expect(screen.getByRole('option', { name: /Jeric/ })).toHaveAttribute('aria-selected', 'true');
    expect(screen.getByText('4')).toBeInTheDocument();
  });

  it('closes on an outside mousedown and on Escape', async () => {
    harness();
    await userEvent.click(screen.getByRole('button', { name: /Mechanic/ }));
    await userEvent.click(screen.getByRole('button', { name: 'outside' }));
    expect(screen.queryByRole('listbox')).not.toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: /Mechanic/ }));
    await userEvent.keyboard('{Escape}');
    expect(screen.queryByRole('listbox')).not.toBeInTheDocument();
  });

  it('clicking the trigger again closes the menu', async () => {
    harness();
    const trigger = screen.getByRole('button', { name: /Mechanic/ });
    await userEvent.click(trigger);
    await userEvent.click(trigger);
    expect(screen.queryByRole('listbox')).not.toBeInTheDocument();
  });

  it('the all row clears the filter', async () => {
    const onChange = harness('m1');
    await userEvent.click(screen.getByRole('button', { name: /Mechanic/ }));
    await userEvent.click(screen.getByRole('option', { name: /All mechanics/ }));
    expect(onChange).toHaveBeenCalledWith('');
  });
});
