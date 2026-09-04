import { describe, expect, it } from 'vitest';
import { parseStockQty, resolveStockChange, validateStockAdjustment, adjustmentValidity } from './resolveStockChange';

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

describe('adjustmentValidity', () => {
  it('rejects when qty is null', () => {
    const result = adjustmentValidity({
      mode: 'add',
      qty: null,
      onHand: 5,
      reasonId: 'ar1',
      requiresNote: false,
      note: '',
    });
    expect(result).toBe('Enter a quantity');
  });

  it('rejects add/remove when qty <= 0', () => {
    expect(
      adjustmentValidity({
        mode: 'add',
        qty: 0,
        onHand: 5,
        reasonId: 'ar1',
        requiresNote: false,
        note: '',
      }),
    ).toBe('Quantity must be greater than 0');

    expect(
      adjustmentValidity({
        mode: 'remove',
        qty: 0,
        onHand: 5,
        reasonId: 'ar1',
        requiresNote: false,
        note: '',
      }),
    ).toBe('Quantity must be greater than 0');
  });

  it('rejects when remove would go negative', () => {
    const result = adjustmentValidity({
      mode: 'remove',
      qty: 10,
      onHand: 5,
      reasonId: 'ar1',
      requiresNote: false,
      note: '',
    });
    expect(result).toBe('Removing 10 would leave -5. Stock cannot go negative.');
  });

  it('rejects when set would go negative', () => {
    const result = adjustmentValidity({
      mode: 'set',
      qty: -2,
      onHand: 5,
      reasonId: 'ar1',
      requiresNote: false,
      note: '',
    });
    expect(result).toBe('Setting to -2 would leave that quantity. Stock cannot go negative.');
  });

  it('rejects when no reason is picked', () => {
    const result = adjustmentValidity({
      mode: 'add',
      qty: 3,
      onHand: 5,
      reasonId: null,
      requiresNote: false,
      note: '',
    });
    expect(result).toBe('Pick a reason');
  });

  it('rejects when a note is required but missing', () => {
    const result = adjustmentValidity({
      mode: 'add',
      qty: 3,
      onHand: 5,
      reasonId: 'ar1',
      requiresNote: true,
      note: '',
    });
    expect(result).toBe('A note is required for this reason');
  });

  it('rejects when a note is required but only whitespace', () => {
    const result = adjustmentValidity({
      mode: 'add',
      qty: 3,
      onHand: 5,
      reasonId: 'ar1',
      requiresNote: true,
      note: '   ',
    });
    expect(result).toBe('A note is required for this reason');
  });

  it('passes a fully valid draft', () => {
    const result = adjustmentValidity({
      mode: 'add',
      qty: 3,
      onHand: 5,
      reasonId: 'ar1',
      requiresNote: false,
      note: '',
    });
    expect(result).toBeNull();
  });

  it('passes when note is not required even if empty', () => {
    const result = adjustmentValidity({
      mode: 'remove',
      qty: 3,
      onHand: 10,
      reasonId: 'ar1',
      requiresNote: false,
      note: '',
    });
    expect(result).toBeNull();
  });

  it('passes when note is required and provided', () => {
    const result = adjustmentValidity({
      mode: 'add',
      qty: 3,
      onHand: 5,
      reasonId: 'ar1',
      requiresNote: true,
      note: 'Found extra units in storage',
    });
    expect(result).toBeNull();
  });

  it('allows set to 0', () => {
    const result = adjustmentValidity({
      mode: 'set',
      qty: 0,
      onHand: 5,
      reasonId: 'ar1',
      requiresNote: false,
      note: '',
    });
    expect(result).toBeNull();
  });

  it('allows large positive set', () => {
    const result = adjustmentValidity({
      mode: 'set',
      qty: 100,
      onHand: 5,
      reasonId: 'ar1',
      requiresNote: false,
      note: '',
    });
    expect(result).toBeNull();
  });
});
