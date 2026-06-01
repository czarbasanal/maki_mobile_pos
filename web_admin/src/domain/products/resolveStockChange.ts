// Resulting quantity for a stock adjustment. Pure -> relative imports. The
// caller validates (qty>0 for add/remove, set>=0, remove<=current).
export type StockMode = 'add' | 'remove' | 'set';

export function resolveStockChange(mode: StockMode, current: number, qty: number): number {
  if (mode === 'add') return current + qty;
  if (mode === 'remove') return current - qty;
  return qty;
}

/** Parse a whole-number quantity from raw input; null unless it is a non-negative
 *  integer. Rejects '', '1.5', '1e3', '+1', '-1', '0x10', whitespace-only, etc. */
export function parseStockQty(text: string): number | null {
  const t = text.trim();
  return /^\d+$/.test(t) ? Number(t) : null;
}

/** Validation message for an adjustment, or null when valid. `qty` comes from
 *  parseStockQty (null = not a whole number). */
export function validateStockAdjustment(
  mode: StockMode,
  current: number,
  qty: number | null,
): string | null {
  if (qty === null) return 'Enter a whole number ≥ 0';
  if ((mode === 'add' || mode === 'remove') && qty <= 0) return 'Quantity must be greater than 0';
  if (mode === 'remove' && qty > current) return 'Cannot remove more than current stock';
  return null;
}
