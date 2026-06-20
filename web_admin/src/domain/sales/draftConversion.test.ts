import { describe, expect, it } from 'vitest';
import { draftConversionOutcome } from './draftConversion';

describe('draftConversionOutcome', () => {
  it('skips when the draft no longer exists (deleted mid-checkout)', () => {
    expect(draftConversionOutcome(false, false)).toBe('skip');
    expect(draftConversionOutcome(false, true)).toBe('skip');
  });
  it('aborts when the draft is already converted (prevents a duplicate sale)', () => {
    expect(draftConversionOutcome(true, true)).toBe('abort');
  });
  it('converts an existing, not-yet-converted draft', () => {
    expect(draftConversionOutcome(true, false)).toBe('convert');
  });
});
