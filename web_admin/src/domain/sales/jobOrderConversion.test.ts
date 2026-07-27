import { describe, expect, it } from 'vitest';
import { jobOrderConversionOutcome } from './jobOrderConversion';

describe('jobOrderConversionOutcome', () => {
  it('skips when the jobOrder no longer exists (deleted mid-checkout)', () => {
    expect(jobOrderConversionOutcome(false, false)).toBe('skip');
    expect(jobOrderConversionOutcome(false, true)).toBe('skip');
  });
  it('aborts when the jobOrder is already converted (prevents a duplicate sale)', () => {
    expect(jobOrderConversionOutcome(true, true)).toBe('abort');
  });
  it('converts an existing, not-yet-converted jobOrder', () => {
    expect(jobOrderConversionOutcome(true, false)).toBe('convert');
  });
});
