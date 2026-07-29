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
      pieces: Number(rec.pieces ?? 1),
      price: Number(rec.price ?? 0),
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
