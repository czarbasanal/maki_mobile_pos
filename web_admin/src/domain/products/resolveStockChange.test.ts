import { describe, expect, it } from 'vitest';
import { resolveStockChange } from './resolveStockChange';

describe('resolveStockChange', () => {
  it('adds to current', () => {
    expect(resolveStockChange('add', 5, 3)).toBe(8);
  });
  it('removes from current', () => {
    expect(resolveStockChange('remove', 5, 3)).toBe(2);
  });
  it('sets the absolute value', () => {
    expect(resolveStockChange('set', 5, 3)).toBe(3);
  });
  it('can go negative on remove (validation is the caller’s job)', () => {
    expect(resolveStockChange('remove', 2, 5)).toBe(-3);
  });
});
