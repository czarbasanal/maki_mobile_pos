// Per-line discount entry (mobile discount_input_dialog.dart parity).
// Hosts the CART-WIDE discount-type toggle: switching type resets every
// line's discount, so when other lines carry one the switch is confirmed
// before it fires — never silent.
import { useState } from 'react';
import { Dialog } from '@/presentation/components/common/Dialog';
import { DiscountType } from '@/domain/enums/DiscountType';
import {
  QUICK_PERCENT_PRESETS,
  discountValidationError,
  quickAmountPresets,
} from '@/domain/sales/discounts';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';

export interface DiscountDialogProps {
  open: boolean;
  onClose: () => void;
  itemName: string;
  currentDiscount: number;
  discountType: DiscountType;
  /** The line's gross — the peso-discount ceiling. */
  maxAmount: number;
  /** Any OTHER line currently discounted — gates the type-switch confirm. */
  hasOtherDiscounts: boolean;
  onApply: (value: number) => void;
  /** Caller updates the cart's type (which resets every line's discount). */
  onTypeChange: (type: DiscountType) => void;
}

export function DiscountDialog({
  open,
  onClose,
  itemName,
  currentDiscount,
  discountType,
  maxAmount,
  hasOtherDiscounts,
  onApply,
  onTypeChange,
}: DiscountDialogProps) {
  const [valueText, setValueText] = useState(currentDiscount ? String(currentDiscount) : '');
  const isPercentage = discountType === DiscountType.percentage;

  const value = valueText.trim() === '' ? 0 : parseFloat(valueText);
  const error = valueText.trim() === '' ? null : discountValidationError(value, isPercentage, maxAmount);
  const canApply = error === null;

  const switchType = (next: DiscountType) => {
    if (next === discountType) return;
    if (
      hasOtherDiscounts &&
      !window.confirm(
        "Switching the discount type resets every line's discount on this ticket. Switch?",
      )
    ) {
      return;
    }
    setValueText('');
    onTypeChange(next);
  };

  const apply = (v: number) => {
    onApply(v);
    onClose();
  };

  const chipCls =
    'rounded-md border border-light-border px-tk-sm py-[4px] text-[12px] text-light-text-secondary hover:bg-light-subtle';

  return (
    <Dialog open={open} onClose={onClose} title={`Discount — ${itemName}`}>
      <div className="space-y-tk-sm">
        <div className="flex gap-tk-xs">
          {(
            [
              [DiscountType.amount, '₱ amount'],
              [DiscountType.percentage, '%'],
            ] as const
          ).map(([type, label]) => (
            <button
              key={type}
              type="button"
              onClick={() => switchType(type)}
              className={cn(
                'rounded-md border px-tk-md py-[6px] text-[12px]',
                type === discountType
                  ? 'border-light-text bg-light-text font-semibold text-light-background'
                  : 'border-light-border text-light-text-secondary hover:bg-light-subtle',
              )}
            >
              {label}
            </button>
          ))}
        </div>

        <label className="block text-[12px] text-light-text-secondary">
          Discount
          <input
            type="text"
            inputMode="decimal"
            value={valueText}
            onChange={(e) => setValueText(e.target.value)}
            placeholder={isPercentage ? 'Enter percentage (0–100)' : `Max: ${formatMoney(maxAmount)}`}
            autoFocus
            className="mt-tk-xs w-full rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-[12px] text-light-text"
          />
        </label>
        {error ? <p className="text-[12px] text-error-dark">{error}</p> : null}

        <div className="flex flex-wrap gap-tk-xs">
          {isPercentage
            ? QUICK_PERCENT_PRESETS.map((p) => (
                <button key={p} type="button" onClick={() => setValueText(String(p))} className={chipCls}>
                  {p}%
                </button>
              ))
            : quickAmountPresets(maxAmount).map((a) => (
                <button key={a} type="button" onClick={() => setValueText(String(a))} className={chipCls}>
                  ₱{a}
                </button>
              ))}
        </div>

        <div className="flex items-center justify-between pt-tk-xs">
          <button
            type="button"
            onClick={() => apply(0)}
            className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-error-dark hover:bg-error-light/40"
          >
            Remove
          </button>
          <div className="flex gap-tk-sm">
            <button
              type="button"
              onClick={onClose}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text-secondary hover:bg-light-subtle"
            >
              Cancel
            </button>
            <button
              type="button"
              disabled={!canApply}
              onClick={() => apply(value)}
              className="rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:cursor-not-allowed disabled:opacity-60"
            >
              Apply
            </button>
          </div>
        </div>
      </div>
    </Dialog>
  );
}
