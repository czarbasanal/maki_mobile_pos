// Mirror of lib/domain/entities/selling_option_entity.dart.

/** One way a product may be sold. `price` is for the WHOLE set. */
export interface SellingOption {
  id: string;
  label: string;
  pieces: number;
  price: number;
}

/** Derived per-piece price, shown as a caption in the POS picker. */
export function sellingOptionPricePerPiece(option: SellingOption): number {
  return option.pieces === 0 ? 0 : option.price / option.pieces;
}

/** Per-piece rate suffix for a product's `unit` — e.g. the "pc" in a
 * "₱110.00/pc" caption. `pcs` is special-cased down to `pc` because it's the
 * only plural default in the product data; every other unit (box, set,
 * pack, ...) is shown exactly as typed. Single source for this mapping —
 * every render site (POS picker, inventory editor, both surfaces) calls
 * this rather than hand-rolling the same conditional. */
export function sellingOptionRateSuffix(unit: string): string {
  return unit === 'pcs' ? 'pc' : unit;
}
