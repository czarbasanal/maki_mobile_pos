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
