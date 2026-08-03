// Web port of the mobile SellingOptionsEditor test suite (see
// test/presentation/mobile/widgets/inventory/selling_options_editor_test.dart)
// — same two review-caught bugs guarded here: a cleared numeric field must
// propagate 0 (not silently keep the stale value), and the margin segment
// must be independently gate-able from the always-shown per-piece price.
//
// `error` is a required prop (Task 15 fix round 1): the host computes
// validateSellingOptions(value) once for its own submit guard and passes the
// result down, rather than this component recomputing it a second time. Every
// render call below computes it the same way a real host would — directly
// from the same `value` being rendered — so these tests still exercise real
// validation output, not a hand-picked string.
import { useState } from 'react';
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { SellingOptionsEditor } from './SellingOptionsEditor';
import { validateSellingOptions } from '@/domain/products/sellingOptions';
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
 * stale `value` prop instead of the state a real host would maintain.
 * `error` is recomputed from `value` on every render, same as a real host's
 * render-time `validateSellingOptions(sellingOptions)` call. */
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
      error={validateSellingOptions(value)}
    />
  );
}

describe('SellingOptionsEditor', () => {
  it('renders one row per option', () => {
    render(
      <SellingOptionsEditor
        value={[by3]}
        onChange={vi.fn()}
        unitCost={60}
        unit="pcs"
        error={validateSellingOptions([by3])}
      />,
    );
    expect(screen.getByDisplayValue('By 3')).toBeInTheDocument();
  });

  it('shows the derived per-piece price', () => {
    render(
      <SellingOptionsEditor
        value={[by3]}
        onChange={vi.fn()}
        unitCost={60}
        unit="pcs"
        error={validateSellingOptions([by3])}
      />,
    );
    // 330 / 3 = 110/pc — a quotient nothing else on screen coincides with.
    expect(screen.getByText(/110/)).toBeInTheDocument();
  });

  it('adds a row with a fresh id', async () => {
    const onChange = vi.fn();
    render(
      <SellingOptionsEditor
        value={[]}
        onChange={onChange}
        unitCost={60}
        unit="pcs"
        error={validateSellingOptions([])}
      />,
    );
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
    render(
      <SellingOptionsEditor
        value={[by3]}
        onChange={onChange}
        unitCost={60}
        unit="pcs"
        error={validateSellingOptions([by3])}
      />,
    );
    await userEvent.click(screen.getByRole('button', { name: /remove/i }));
    expect(onChange).toHaveBeenCalledWith([]);
  });

  it('removing the first of two rows keeps the second option — catches index/id confusion', async () => {
    const onChange = vi.fn();
    render(
      <SellingOptionsEditor
        value={[by6, by3]}
        onChange={onChange}
        unitCost={60}
        unit="pcs"
        error={validateSellingOptions([by6, by3])}
      />,
    );
    const removeButtons = screen.getAllByRole('button', { name: /remove/i });
    await userEvent.click(removeButtons[0]);
    expect(onChange).toHaveBeenCalledWith([by3]);
  });

  it('shows the add control under the 10-option cap (9 options) — paired with the cap test below, so an always-hidden control also fails', () => {
    const nine = tenOptions().slice(0, 9);
    render(
      <SellingOptionsEditor
        value={nine}
        onChange={vi.fn()}
        unitCost={60}
        unit="pcs"
        error={validateSellingOptions(nine)}
      />,
    );
    expect(screen.getByRole('button', { name: /add option/i })).toBeInTheDocument();
  });

  it('hides the add control at the 10-option cap — paired with the 9-option test above, so an always-shown control also fails', () => {
    const ten = tenOptions();
    render(
      <SellingOptionsEditor
        value={ten}
        onChange={vi.fn()}
        unitCost={60}
        unit="pcs"
        error={validateSellingOptions(ten)}
      />,
    );
    expect(screen.queryByRole('button', { name: /add option/i })).toBeNull();
  });

  it('shows the exact validation message for a duplicate label — catches a generic/placeholder error string', () => {
    const dup = [by3, { ...by3, id: 'o9' }];
    render(
      <SellingOptionsEditor
        value={dup}
        onChange={vi.fn()}
        unitCost={60}
        unit="pcs"
        error={validateSellingOptions(dup)}
      />,
    );
    expect(screen.getByText('Option labels must be unique — "By 3" is used twice.')).toBeInTheDocument();
  });

  it('shows the exact validation message for less than 1 piece', () => {
    const zeroPieces = [{ ...by3, pieces: 0 }];
    render(
      <SellingOptionsEditor
        value={zeroPieces}
        onChange={vi.fn()}
        unitCost={60}
        unit="pcs"
        error={validateSellingOptions(zeroPieces)}
      />,
    );
    expect(screen.getByText('"By 3" must cover at least 1 piece.')).toBeInTheDocument();
  });

  it('shows the exact validation message for a non-positive price', () => {
    const zeroPrice = [{ ...by3, price: 0 }];
    render(
      <SellingOptionsEditor
        value={zeroPrice}
        onChange={vi.fn()}
        unitCost={60}
        unit="pcs"
        error={validateSellingOptions(zeroPrice)}
      />,
    );
    expect(screen.getByText('"By 3" needs a price above zero.')).toBeInTheDocument();
  });

  it('shows no validation message for an already-valid list', () => {
    render(
      <SellingOptionsEditor
        value={[by3]}
        onChange={vi.fn()}
        unitCost={60}
        unit="pcs"
        error={validateSellingOptions([by3])}
      />,
    );
    expect(screen.queryByText(/must cover|needs a price|unique|At most/)).toBeNull();
  });

  it('renders whatever error string the host passes, verbatim — the component no longer computes its own', () => {
    // A valid list (by3 alone has no validation error) paired with a
    // host-supplied error proves the message comes from the prop, not from
    // an internal recomputation — a component that ignored `error` and
    // recomputed validateSellingOptions(value) itself would show nothing
    // here instead.
    render(
      <SellingOptionsEditor
        value={[by3]}
        onChange={vi.fn()}
        unitCost={60}
        unit="pcs"
        error="Host-supplied message that validateSellingOptions([by3]) would never produce"
      />,
    );
    expect(
      screen.getByText('Host-supplied message that validateSellingOptions([by3]) would never produce'),
    ).toBeInTheDocument();
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
    render(
      <SellingOptionsEditor
        value={[by3]}
        onChange={vi.fn()}
        unitCost={60}
        unit="pcs"
        showMargin
        error={validateSellingOptions([by3])}
      />,
    );
    // 330/3 = 110/pc; (110-60)/110 = 45% margin.
    expect(screen.getByText(`${formatMoney(110)}/pc · 45% margin`)).toBeInTheDocument();
  });

  it('uses the product\'s own unit as the per-piece suffix, not a hardcoded "pc"', () => {
    render(
      <SellingOptionsEditor
        value={[by3]}
        onChange={vi.fn()}
        unitCost={60}
        unit="box"
        error={validateSellingOptions([by3])}
      />,
    );
    // 330 / 3 = 110/box. A hardcoded "pc" suffix would show "/pc" here
    // regardless of the `unit` prop.
    expect(screen.getByText(new RegExp(`${formatMoney(110)}/box`))).toBeInTheDocument();
  });

  it('hides the margin segment when showMargin is false but keeps the per-piece price — catches gating the whole caption instead of just the cost-derived half', () => {
    render(
      <SellingOptionsEditor
        value={[by3]}
        onChange={vi.fn()}
        unitCost={60}
        unit="pcs"
        showMargin={false}
        error={validateSellingOptions([by3])}
      />,
    );
    expect(screen.getByText(`${formatMoney(110)}/pc`)).toBeInTheDocument();
    expect(screen.queryByText(/margin/)).toBeNull();
  });
});
