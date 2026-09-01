import { describe, expect, it } from 'vitest';
import { percentDelta } from './compare';

describe('percentDelta', () => {
  it('signed fraction vs prior day', () => {
    expect(percentDelta(27, 25)).toBeCloseTo(0.08);
    expect(percentDelta(20, 25)).toBeCloseTo(-0.2);
  });
  it('null when there is no baseline', () => {
    expect(percentDelta(27, 0)).toBeNull();
  });
});
