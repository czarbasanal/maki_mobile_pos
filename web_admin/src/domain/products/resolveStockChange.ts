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

/** Complete draft data for a stock adjustment, combining the parsed quantity,
 *  on-hand before the adjustment, the selected reason (if any), and a note. */
export interface AdjustmentDraft {
  mode: StockMode;
  qty: number | null;          // from parseStockQty
  onHand: number;
  reasonId: string | null;
  requiresNote: boolean;       // the picked reason's flag (false when none picked)
  note: string;
}

/** Validation message for an adjustment draft, or null when the draft can be
 *  applied. Combines quantity validation, reason selection, and note requirement.
 *  Negative results reuse the guide's copy:
 *  `Removing ${qty} would leave ${after}. Stock cannot go negative.` */
export function adjustmentValidity(d: AdjustmentDraft): string | null {
  // Validate quantity is present
  if (d.qty === null) return 'Enter a quantity';

  // Validate quantity is positive for add/remove modes
  if ((d.mode === 'add' || d.mode === 'remove') && d.qty <= 0) {
    return 'Quantity must be greater than 0';
  }

  // Calculate what the stock would be after this adjustment
  const after = resolveStockChange(d.mode, d.onHand, d.qty);

  // Reject negative results. remove mode shows the guide's sentence;
  // other modes (unreachable in normal UI) return plain message.
  if (after < 0) {
    if (d.mode === 'remove') {
      return `Removing ${d.qty} would leave ${after}. Stock cannot go negative.`;
    } else {
      return 'Stock cannot go negative.';
    }
  }

  // Require a reason to be selected
  if (d.reasonId === null) return 'Pick a reason';

  // Require a note if the reason's requiresNote flag is set
  if (d.requiresNote && d.note.trim() === '') {
    return 'A note is required for this reason';
  }

  return null;
}
