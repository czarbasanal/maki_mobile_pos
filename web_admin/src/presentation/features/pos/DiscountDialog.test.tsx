import { afterEach, describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { DiscountDialog } from './DiscountDialog';
import { DiscountType } from '@/domain/enums/DiscountType';

afterEach(() => vi.restoreAllMocks());

function harness(over: Partial<Parameters<typeof DiscountDialog>[0]> = {}) {
  const onApply = vi.fn();
  const onTypeChange = vi.fn();
  const onClose = vi.fn();
  render(
    <DiscountDialog
      open
      onClose={onClose}
      itemName="Brake shoe"
      currentDiscount={0}
      discountType={DiscountType.amount}
      maxAmount={400}
      hasOtherDiscounts={false}
      onApply={onApply}
      onTypeChange={onTypeChange}
      {...over}
    />,
  );
  return { onApply, onTypeChange, onClose };
}

describe('DiscountDialog', () => {
  it('quick chip fills the value and Apply sends it', async () => {
    const { onApply } = harness();
    await userEvent.click(screen.getByRole('button', { name: '₱50' }));
    await userEvent.click(screen.getByRole('button', { name: /^apply$/i }));
    expect(onApply).toHaveBeenCalledWith(50);
  });

  it('percent mode: >100 shows the error and blocks Apply', async () => {
    const { onApply } = harness({ discountType: DiscountType.percentage });
    await userEvent.type(screen.getByRole('textbox', { name: /^discount$/i }), '120');
    expect(screen.getByText('Cannot exceed 100%')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /^apply$/i })).toBeDisabled();
    expect(onApply).not.toHaveBeenCalled();
  });

  it('amount mode: caps at the line total', async () => {
    harness();
    await userEvent.type(screen.getByRole('textbox', { name: /^discount$/i }), '500');
    expect(screen.getByText('Cannot exceed item total (₱400.00)')).toBeInTheDocument();
  });

  it('Remove applies zero', async () => {
    const { onApply } = harness({ currentDiscount: 25 });
    await userEvent.click(screen.getByRole('button', { name: /remove/i }));
    expect(onApply).toHaveBeenCalledWith(0);
  });

  it('type switch with other discounted lines asks for confirmation first', async () => {
    const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(false);
    const { onTypeChange } = harness({ hasOtherDiscounts: true });
    await userEvent.click(screen.getByRole('button', { name: /%$/ }));
    expect(confirmSpy).toHaveBeenCalled();
    expect(onTypeChange).not.toHaveBeenCalled();

    confirmSpy.mockReturnValue(true);
    await userEvent.click(screen.getByRole('button', { name: /%$/ }));
    expect(onTypeChange).toHaveBeenCalledWith(DiscountType.percentage);
  });

  it('type switch with no other discounts needs no confirmation', async () => {
    const confirmSpy = vi.spyOn(window, 'confirm');
    const { onTypeChange } = harness({ hasOtherDiscounts: false });
    await userEvent.click(screen.getByRole('button', { name: /%$/ }));
    expect(confirmSpy).not.toHaveBeenCalled();
    expect(onTypeChange).toHaveBeenCalledWith(DiscountType.percentage);
  });
});
