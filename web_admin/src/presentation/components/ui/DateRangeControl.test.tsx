// The skinned range calendar (design/maki-pos-date-range-calendar): one
// calendar, two clicks; reversed picks swap; both-set restarts; Apply is
// explicit and the applied span replaces "Custom" on the pill.
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState } from 'react';
import { DateRangeControl } from './DateRangeControl';
import { shopIsoDate } from '@/domain/time/shopTime';

const OPTIONS = [
  { value: 'today', label: 'Today' },
  { value: 'last30', label: '30 days' },
  { value: 'custom', label: 'Custom' },
];

function Harness({
  onStart = () => {},
  onEnd = () => {},
  initial = { start: '', end: '' },
  initialValue = 'last30',
}: {
  onStart?: (v: string) => void;
  onEnd?: (v: string) => void;
  initial?: { start: string; end: string };
  initialValue?: string;
}) {
  const [value, setValue] = useState(initialValue);
  const [start, setStart] = useState(initial.start);
  const [end, setEnd] = useState(initial.end);
  return (
    <DateRangeControl
      options={OPTIONS}
      value={value}
      onChange={setValue}
      customStart={start}
      customEnd={end}
      onCustomStart={(v) => {
        setStart(v);
        onStart(v);
      }}
      onCustomEnd={(v) => {
        setEnd(v);
        onEnd(v);
      }}
    />
  );
}

/** Two shop-today-anchored keys guaranteed to be in the visible month and
 *  pickable (<= today): today and the 1st of today's month. */
function keys() {
  const today = shopIsoDate(new Date());
  const first = `${today.slice(0, 8)}01`;
  return { today, first };
}

async function openCalendar() {
  await userEvent.click(screen.getByRole('radio', { name: 'Custom' }));
  return screen.getByRole('dialog', { name: /pick a date range/i });
}

describe('DateRangeControl calendar', () => {
  it('always renders 42 day cells plus the weekday header', async () => {
    render(<Harness />);
    const dialog = await openCalendar();
    const cells = dialog.querySelectorAll('.grid > button');
    expect(cells).toHaveLength(42);
  });

  it('first click sets From, second sets To, Apply pushes both', async () => {
    const onStart = vi.fn();
    const onEnd = vi.fn();
    render(<Harness onStart={onStart} onEnd={onEnd} />);
    const { today, first } = keys();
    await openCalendar();

    expect(screen.getByText('Click a day to start')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: first }));
    expect(screen.getByText('Click a second day to end')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: today }));
    expect(screen.getByText('Range set')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Apply' }));
    expect(onStart).toHaveBeenCalledWith(first);
    expect(onEnd).toHaveBeenCalledWith(today);
    // Calendar closes on Apply; the pill now shows the span, not "Custom".
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(screen.queryByRole('radio', { name: 'Custom' })).not.toBeInTheDocument();
  });

  it('a click before From swaps the pair instead of erroring', async () => {
    const onStart = vi.fn();
    const onEnd = vi.fn();
    render(<Harness onStart={onStart} onEnd={onEnd} />);
    const { today, first } = keys();
    if (today === first) return; // 1st of the month: nothing earlier to swap with
    await openCalendar();

    await userEvent.click(screen.getByRole('button', { name: today }));
    await userEvent.click(screen.getByRole('button', { name: first }));
    await userEvent.click(screen.getByRole('button', { name: 'Apply' }));
    expect(onStart).toHaveBeenCalledWith(first);
    expect(onEnd).toHaveBeenCalledWith(today);
  });

  it('Apply is inert until both ends exist; Reset clears the pick', async () => {
    const onStart = vi.fn();
    render(<Harness onStart={onStart} />);
    const { first } = keys();
    await openCalendar();

    await userEvent.click(screen.getByRole('button', { name: first }));
    await userEvent.click(screen.getByRole('button', { name: 'Apply' }));
    expect(onStart).not.toHaveBeenCalled();
    expect(screen.getByRole('dialog')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Reset' }));
    expect(screen.getByText('Click a day to start')).toBeInTheDocument();
  });

  it('closes on Escape and on re-clicking the Custom pill', async () => {
    render(<Harness />);
    await openCalendar();
    await userEvent.keyboard('{Escape}');
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();

    await userEvent.click(screen.getByRole('radio', { name: 'Custom' }));
    expect(screen.getByRole('dialog')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('radio', { name: 'Custom' }));
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  it('month navigation moves the header label', async () => {
    render(<Harness />);
    await openCalendar();
    const before = screen.getByText(/^[A-Z][a-z]+ \d{4}$/).textContent;
    await userEvent.click(screen.getByRole('button', { name: 'Previous month' }));
    const after = screen.getByText(/^[A-Z][a-z]+ \d{4}$/).textContent;
    expect(after).not.toBe(before);
  });

  it('an applied range replaces the Custom pill label with the span', async () => {
    render(<Harness initial={{ start: '2026-09-01', end: '2026-09-03' }} initialValue="custom" />);
    await userEvent.click(screen.getByRole('radio', { name: /Sep 1 – Sep 3/ }));
    expect(screen.getByRole('dialog')).toBeInTheDocument();
  });
});
