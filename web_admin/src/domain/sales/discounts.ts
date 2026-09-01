// Per-line discount dialog rules — mirror of mobile's
// discount_input_dialog.dart (quick chips + validation).
import { formatMoney } from '@/core/utils/money';

export const QUICK_PERCENT_PRESETS = [5, 10, 15, 20, 25, 50];

/** Peso quick-chip presets, tiered by the line's gross and filtered to it. */
export function quickAmountPresets(maxAmount: number): number[] {
  let amounts: number[];
  if (maxAmount <= 100) amounts = [5, 10, 20, 50];
  else if (maxAmount <= 500) amounts = [10, 20, 50, 100];
  else if (maxAmount <= 1000) amounts = [50, 100, 200, 500];
  else amounts = [100, 200, 500, 1000];
  return amounts.filter((a) => a <= maxAmount);
}

export function discountValidationError(
  value: number,
  isPercentage: boolean,
  maxAmount: number,
): string | null {
  if (!Number.isFinite(value) || value < 0) return 'Enter a valid amount';
  if (isPercentage && value > 100) return 'Cannot exceed 100%';
  if (!isPercentage && value > maxAmount) {
    return `Cannot exceed item total (${formatMoney(maxAmount)})`;
  }
  return null;
}
