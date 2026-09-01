import { describe, expect, it } from 'vitest';
import { canonicalModelName, normalizedModelKey } from './MotorcycleModel';

describe('motorcycle model names', () => {
  it('canonical form trims and collapses whitespace, preserving case', () => {
    expect(canonicalModelName('  Nmax   155 ')).toBe('Nmax 155');
  });
  it('normalized key is the case-insensitive dedup key', () => {
    expect(normalizedModelKey('  nmax ')).toBe(normalizedModelKey('Nmax'));
    expect(normalizedModelKey('Click 125i')).toBe('click 125i');
  });
});
