// Web port of the mobile SellingOptionsEditor test suite (see
// test/presentation/mobile/widgets/inventory/selling_options_editor_test.dart)
// — same two review-caught bugs guarded here: a cleared numeric field must
// propagate 0 (not silently keep the stale value), and the margin segment
// must be independently gate-able from the always-shown per-piece price.
import { useState } from 'react';
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { SellingOptionsEditor } from './SellingOptionsEditor';
import { formatMoney } from '@/core/utils/money';
import type { SellingOption } from '@/domain/entities/SellingOption';

const by3: SellingOption = { id: 'o2', label: 'By 3', pieces: 3, price: 330 };
const by6: SellingOption = { id: 'o1', label: 'By 6', pieces: 6, price: 600 };

function tenOptions(): SellingOption[] {
  return Array.from({ length: 10 }, (_, i) => ({
    id: `${i}`,
    label: `By ${i}`,
    pieces: i + 1,
    price: 100,
  }));
}

/** Real controlled-component usage: feeds onChange's next list back in as the
 * next `value`, same as the mobile test file's StatefulBuilder harness. Tests
 * that build on more than one interaction (add-twice, clear-then-type) need
 * this — without it, the component would keep re-deriving from the same
 * stale `value` prop instead of the state a real host would maintain. */
function Harness({
  initial,
  onChange,
  unitCost = 60,
  unit = 'pcs',
  showMargin = true,
}: {
  initial: SellingOption[];
  onChange: (next: SellingOption[]) => void;
  unitCost?: number;
  unit?: string;
  showMargin?: boolean;
}) {
  const [value, setValue] = useState(initial);
  return (
    <SellingOptionsEditor
      value={value}
      onChange={(next) => {
        setValue(next);
        onChange(next);
      }}
      unitCost={unitCost}
      unit={unit}
      showMargin={showMargin}
    />
  );
}

describe('SellingOptionsEditor', () => {
  it('renders one row per option', () => {
    render(<SellingOptionsEditor value={[by3]} onChange={vi.fn()} unitCost={60} unit="pcs" />);
    expect(screen.getByDisplayValue('By 3')).toBeInTheDocument();
  });

  it('shows the derived per-piece price', () => {
    render(<SellingOptionsEditor value={[by3]} onChange={vi.fn()} unitCost={60} unit="pcs" />);
    // 330 / 3 = 110/pc — a quotient nothing else on screen coincides with.
    expect(screen.getByText(/110/)).toBeInTheDocument();
  });

  it('adds a row with a fresh id', async () => {
    const onChange = vi.fn();
    render(<SellingOptionsEditor value={[]} onChange={onChange} unitCost={60} unit="pcs" />);
    await userEvent.click(screen.getByRole('button', { name: /add option/i }));
    expect(onChange).toHaveBeenCalledWith([expect.objectContaining({ id: expect.any(String) })]);
  });

  it('adding twice mints two distinct, non-empty ids — catches a hardcoded/reused id', async () => {
    const onChange = vi.fn();
    render(<Harness initial={[]} onChange={onChange} />);
    const addButton = screen.getByRole('button', { name: /add option/i });
    await userEvent.click(addButton);
    await userEvent.click(addButton);

    const firstId = (onChange.mock.calls[0][0] as SellingOption[])[0].id;
    const secondId = (onChange.mock.calls[1][0] as SellingOption[])[1].id;
    expect(firstId).not.toBe('');
    expect(secondId).not.toBe('');
    expect(firstId).not.toBe(secondId);
  });

  it('removes a row', async () => {
    const onChange = vi.fn();
    render(<SellingOptionsEditor value={[by3]} onChange={onChange} unitCost={60} unit="pcs" />);
    await userEvent.click(screen.getByRole('button', { name: /remove/i }));
    expect(onChange).toHaveBeenCalledWith([]);
  });

  it('removing the first of two rows keeps the second option — catches index/id confusion', async () => {
    const onChange = vi.fn();
    render(<SellingOptionsEditor value={[by6, by3]} onChange={onChange} unitCost={60} unit="pcs" />);
    const removeButtons = screen.getAllByRole('button', { name: /remove/i });
    await userEvent.click(removeButtons[0]);
    expect(onChange).toHaveBeenCalledWith([by3]);
  });

  it('shows the add control under the 10-option cap (9 options) — paired with the cap test below, so an always-hidden control also fails', () => {
    const nine = tenOptions().slice(0, 9);
    render(<SellingOptionsEditor value={nine} onChange={vi.fn()} unitCost={60} unit="pcs" />);
    expect(screen.getByRole('button', { name: /add option/i })).toBeInTheDocument();
  });

  it('hides the add control at the 10-option cap — paired with the 9-option test above, so an always-shown control also fails', () => {
    render(<SellingOptionsEditor value={tenOptions()} onChange={vi.fn()} unitCost={60} unit="pcs" />);
    expect(screen.queryByRole('button', { name: /add option/i })).toBeNull();
  });

  it('shows the exact validation message for a duplicate label — catches a generic/placeholder error string', () => {
    render(
      <SellingOptionsEditor
        value={[by3, { ...by3, id: 'o9' }]}
        onChange={vi.fn()}
        unitCost={60}
        unit="pcs"
      />,
    );
    expect(screen.getByText('Option labels must be unique — "By 3" is used twice.')).toBeInTheDocument();
  });

  it('shows the exact validation message for less than 1 piece', () => {
    render(
      <SellingOptionsEditor value={[{ ...by3, pieces: 0 }]} onChange={vi.fn()} unitCost={60} unit="pcs" />,
    );
    expect(screen.getByText('"By 3" must cover at least 1 piece.')).toBeInTheDocument();
  });

  it('shows the exact validation message for a non-positive price', () => {
    render(
      <SellingOptionsEditor value={[{ ...by3, price: 0 }]} onChange={vi.fn()} unitCost={60} unit="pcs" />,
    );
    expect(screen.getByText('"By 3" needs a price above zero.')).toBeInTheDocument();
  });

  it('shows no validation message for an already-valid list', () => {
    render(<SellingOptionsEditor value={[by3]} onChange={vi.fn()} unitCost={60} unit="pcs" />);
    expect(screen.queryByText(/must cover|needs a price|unique|At most/)).toBeNull();
  });

  it('editing the label propagates the new label without minting a new id', async () => {
    const onChange = vi.fn();
    render(<Harness initial={[by3]} onChange={onChange} />);
    const input = screen.getByDisplayValue('By 3');
    await userEvent.clear(input);
    await userEvent.type(input, 'By Six');

    const last = onChange.mock.calls.at(-1)?.[0] as SellingOption[];
    expect(last[0].label).toBe('By Six');
    expect(last[0].id).toBe(by3.id);
  });

  it('editing the pieces field updates pieces and recomputes the caption', async () => {
    const onChange = vi.fn();
    render(<Harness initial={[by3]} onChange={onChange} />);
    const input = screen.getByRole('spinbutton', { name: 'Pieces' });
    await userEvent.clear(input);
    await userEvent.type(input, '6');

    const last = onChange.mock.calls.at(-1)?.[0] as SellingOption[];
    expect(last[0].pieces).toBe(6);
    // 330 / 6 = 55/pc — distinct from the original 110/pc.
    expect(screen.getByText(new RegExp(`${formatMoney(55)}/pc`))).toBeInTheDocument();
  });

  it('editing the price field updates price and recomputes the caption', async () => {
    const onChange = vi.fn();
    render(<Harness initial={[by3]} onChange={onChange} />);
    const input = screen.getByRole('spinbutton', { name: 'Price' });
    await userEvent.clear(input);
    await userEvent.type(input, '360');

    const last = onChange.mock.calls.at(-1)?.[0] as SellingOption[];
    expect(last[0].price).toBe(360);
    // 360 / 3 = 120/pc — distinct from the original 110/pc.
    expect(screen.getByText(new RegExp(`${formatMoney(120)}/pc`))).toBeInTheDocument();
  });

  it('clearing the pieces field propagates 0 to onChange (not the stale value) and surfaces the "must cover" error — catches silently keeping the old value on a parse failure', async () => {
    const onChange = vi.fn();
    render(<Harness initial={[by3]} onChange={onChange} />);
    const input = screen.getByRole('spinbutton', { name: 'Pieces' });
    await userEvent.clear(input);

    const last = onChange.mock.calls.at(-1)?.[0] as SellingOption[];
    expect(last[0].pieces).toBe(0);
    expect(screen.getByText(/must cover at least 1 piece/)).toBeInTheDocument();
  });

  it('clearing the price field propagates 0 to onChange (not the stale value) and surfaces the "needs a price" error — catches silently keeping the old value on a parse failure', async () => {
    const onChange = vi.fn();
    render(<Harness initial={[by3]} onChange={onChange} />);
    const input = screen.getByRole('spinbutton', { name: 'Price' });
    await userEvent.clear(input);

    const last = onChange.mock.calls.at(-1)?.[0] as SellingOption[];
    expect(last[0].price).toBe(0);
    expect(screen.getByText(/needs a price above zero/)).toBeInTheDocument();
  });

  it('clearing then typing "6" shows "6", not "06" — catches echoing the parsed value back into the field\'s displayed text', async () => {
    const onChange = vi.fn();
    render(<Harness initial={[by3]} onChange={onChange} />);
    const input = screen.getByRole('spinbutton', { name: 'Pieces' }) as HTMLInputElement;
    await userEvent.clear(input);
    // Asserted immediately after the clear (before any further keystroke can
    // re-parse and self-heal the display): an implementation that renders
    // the input's value from the entity (rather than its own local text)
    // would show "3" (stale, bug 1) or "0" (bug 1 fixed but bug 2 present)
    // here instead of blank.
    expect(input.value).toBe('');
    await userEvent.type(input, '6');

    expect(input.value).toBe('6');
    const last = onChange.mock.calls.at(-1)?.[0] as SellingOption[];
    expect(last[0].pieces).toBe(6);
  });

  it('shows the margin segment alongside the per-piece price when showMargin is true', () => {
    render(<SellingOptionsEditor value={[by3]} onChange={vi.fn()} unitCost={60} unit="pcs" showMargin />);
    // 330/3 = 110/pc; (110-60)/110 = 45% margin.
    expect(screen.getByText(`${formatMoney(110)}/pc · 45% margin`)).toBeInTheDocument();
  });

  it('hides the margin segment when showMargin is false but keeps the per-piece price — catches gating the whole caption instead of just the cost-derived half', () => {
    render(
      <SellingOptionsEditor value={[by3]} onChange={vi.fn()} unitCost={60} unit="pcs" showMargin={false} />,
    );
    expect(screen.getByText(`${formatMoney(110)}/pc`)).toBeInTheDocument();
    expect(screen.queryByText(/margin/)).toBeNull();
  });
});
