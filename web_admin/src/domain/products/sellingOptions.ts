// Port of lib/core/utils/selling_options.dart. Pure -> relative imports.
import type { SellingOption } from '../entities/SellingOption';

export const MAX_SELLING_OPTIONS = 10;
export const MAX_SELLING_OPTION_LABEL = 24;

/** Returns null when valid, otherwise a message for the product form. */
export function validateSellingOptions(options: SellingOption[]): string | null {
  if (options.length === 0) return null;
  if (options.length > MAX_SELLING_OPTIONS) {
    return `At most ${MAX_SELLING_OPTIONS} selling options per product.`;
  }

  const seen = new Set<string>();
  for (const option of options) {
    const label = option.label.trim();
    if (label === '') return 'Every selling option needs a label.';
    if (label.length > MAX_SELLING_OPTION_LABEL) {
      return `Option labels are limited to ${MAX_SELLING_OPTION_LABEL} characters.`;
    }
    const key = label.toLowerCase();
    if (seen.has(key)) return `Option labels must be unique — "${label}" is used twice.`;
    seen.add(key);
    if (option.pieces < 1) return `"${label}" must cover at least 1 piece.`;
    if (option.price <= 0) return `"${label}" needs a price above zero.`;
  }
  return null;
}

/**
 * Tolerant parse of the Firestore `sellingOptions` array. A missing field,
 * wrong type or malformed entry yields no option rather than throwing, so one
 * bad doc can never break the product list.
 */
export function parseSellingOptions(raw: unknown): SellingOption[] {
  if (!Array.isArray(raw)) return [];
  const result: SellingOption[] = [];
  for (const item of raw) {
    if (typeof item !== 'object' || item === null) continue;
    const rec = item as Record<string, unknown>;
    const id = typeof rec.id === 'string' ? rec.id : '';
    const label = typeof rec.label === 'string' ? rec.label : '';
    if (id === '' || label === '') continue;
    result.push({
      id,
      label,
      pieces: typeof rec.pieces === 'number' && Number.isFinite(rec.pieces) ? Math.trunc(rec.pieces) : 1,
      price: typeof rec.price === 'number' && Number.isFinite(rec.price) ? rec.price : 0,
    });
  }
  return result;
}

export function serializeSellingOptions(options: SellingOption[]): object[] {
  return options.map((o) => ({
    id: o.id,
    label: o.label,
    pieces: o.pieces,
    price: o.price,
  }));
}

/** One price_history entry to write for a selling-option change. */
export interface SellingOptionHistoryEvent {
  optionId: string;
  optionLabel: string;
  optionPieces: number;
  /** Price of the whole set. */
  price: number;
  /** Cost of the whole set — pieces x unit cost — so the report's margin
   *  column compares like with like against `price`. */
  cost: number;
  reason: string;
}

/** One centavo. Matches the threshold `priceHistoryReason` already uses, so a
 *  rounding wobble never writes a history entry. */
const HISTORY_EPS = 0.01;

/**
 * Diffs a product's selling options and returns the price_history entries to
 * write. Label-only renames produce nothing — a rename isn't a price event.
 */
export function sellingOptionHistoryEvents(
  before: SellingOption[],
  after: SellingOption[],
  unitCost: number,
): SellingOptionHistoryEvent[] {
  const beforeById = new Map(before.map((o) => [o.id, o]));
  const afterById = new Map(after.map((o) => [o.id, o]));
  const events: SellingOptionHistoryEvent[] = [];

  const toEvent = (o: SellingOption, reason: string): SellingOptionHistoryEvent => ({
    optionId: o.id,
    optionLabel: o.label,
    optionPieces: o.pieces,
    price: o.price,
    cost: o.pieces * unitCost,
    reason,
  });

  for (const o of after) {
    const prior = beforeById.get(o.id);
    if (prior === undefined) {
      events.push(toEvent(o, 'Option added'));
      continue;
    }
    const piecesChanged = prior.pieces !== o.pieces;
    const priceChanged = Math.abs(prior.price - o.price) > HISTORY_EPS;
    if (piecesChanged) {
      events.push(toEvent(o, 'Option changed'));
    } else if (priceChanged) {
      events.push(toEvent(o, 'Price update'));
    }
  }

  for (const o of before) {
    if (!afterById.has(o.id)) events.push(toEvent(o, 'Option removed'));
  }

  return events;
}
