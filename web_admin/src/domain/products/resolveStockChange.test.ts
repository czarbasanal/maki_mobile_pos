import { describe, expect, it } from 'vitest';
import { parseStockQty, resolveStockChange, validateStockAdjustment } from './resolveStockChange';

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

describe('parseStockQty', () => {
  it('accepts non-negative whole numbers (and trims)', () => {
    expect(parseStockQty('5')).toBe(5);
    expect(parseStockQty(' 0 ')).toBe(0);
  });
  it('rejects decimals, exponent, signs, hex, blank', () => {
    for (const t of ['', '   ', '1.5', '1e3', '+1', '-1', '0x10', '.5', 'abc']) {
      expect(parseStockQty(t)).toBeNull();
    }
  });
});

describe('validateStockAdjustment', () => {
  it('requires a parsed number', () => {
    expect(validateStockAdjustment('add', 5, null)).toBe('Enter a whole number ≥ 0');
  });
  it('add/remove require > 0', () => {
    expect(validateStockAdjustment('add', 5, 0)).toBe('Quantity must be greater than 0');
    expect(validateStockAdjustment('remove', 5, 0)).toBe('Quantity must be greater than 0');
  });
  it('set allows 0', () => {
    expect(validateStockAdjustment('set', 5, 0)).toBeNull();
  });
  it('remove cannot exceed current stock', () => {
    expect(validateStockAdjustment('remove', 5, 6)).toBe('Cannot remove more than current stock');
  });
  it('passes a valid adjustment', () => {
    expect(validateStockAdjustment('add', 5, 3)).toBeNull();
    expect(validateStockAdjustment('remove', 5, 5)).toBeNull();
  });
});
