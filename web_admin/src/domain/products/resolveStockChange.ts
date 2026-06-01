// Resulting quantity for a stock adjustment. Pure -> relative imports. The
// caller validates (qty>0 for add/remove, set>=0, remove<=current).
export type StockMode = 'add' | 'remove' | 'set';

export function resolveStockChange(mode: StockMode, current: number, qty: number): number {
  if (mode === 'add') return current + qty;
  if (mode === 'remove') return current - qty;
  return qty;
}
