import { describe, expect, it } from 'vitest';
import {
  QUICK_PERCENT_PRESETS,
  discountValidationError,
  quickAmountPresets,
} from './discounts';

describe('quickAmountPresets (mobile tier parity)', () => {
  it('tiers by the line total', () => {
    expect(quickAmountPresets(80)).toEqual([5, 10, 20, 50]);
    expect(quickAmountPresets(400)).toEqual([10, 20, 50, 100]);
    expect(quickAmountPresets(900)).toEqual([50, 100, 200, 500]);
    expect(quickAmountPresets(5000)).toEqual([100, 200, 500, 1000]);
  });
  it('drops presets above the line total', () => {
    expect(quickAmountPresets(30)).toEqual([5, 10, 20]);
  });
});

describe('discountValidationError', () => {
  it('caps percentage at 100', () => {
    expect(discountValidationError(120, true, 500)).toBe('Cannot exceed 100%');
    expect(discountValidationError(100, true, 500)).toBeNull();
  });
  it('caps amount at the line total', () => {
    expect(discountValidationError(600, false, 500)).toBe('Cannot exceed item total (₱500.00)');
    expect(discountValidationError(500, false, 500)).toBeNull();
  });
  it('rejects negatives and NaN', () => {
    expect(discountValidationError(-1, false, 500)).toBe('Enter a valid amount');
    expect(discountValidationError(NaN, true, 500)).toBe('Enter a valid amount');
  });
});

describe('QUICK_PERCENT_PRESETS', () => {
  it('matches mobile', () => expect(QUICK_PERCENT_PRESETS).toEqual([5, 10, 15, 20, 25, 50]));
});
