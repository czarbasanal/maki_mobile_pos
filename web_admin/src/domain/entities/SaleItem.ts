// Mirror of lib/domain/entities/sale_item_entity.dart.
export interface SaleItem {
  id: string;
  productId: string;
  sku: string;
  name: string;
  unitPrice: number;
  unitCost: number;
  quantity: number;
  discountValue: number;
  unit: string;
  /** Snapshot of the selling option used for this line, if any. Kept on the
   * line rather than looked up, so editing or deleting the option later
   * never rewrites a past receipt. */
  optionId: string | null;
  optionLabel: string | null;
  optionPieces: number | null;
  /** Price of one whole set, as typed by the admin. unitPrice is this
   * divided by optionPieces; this field is what the receipt shows. */
  optionPrice: number | null;
}

export function saleItemGross(item: SaleItem): number {
  return item.unitPrice * item.quantity;
}

export function saleItemTotalCost(item: SaleItem): number {
  return item.unitCost * item.quantity;
}

export function saleItemDiscountAmount(item: SaleItem, isPercentage: boolean): number {
  if (item.discountValue <= 0) return 0;
  if (isPercentage) return saleItemGross(item) * (item.discountValue / 100);
  // Cap discount at gross to avoid negative net.
  return Math.min(item.discountValue, saleItemGross(item));
}

export function saleItemNet(item: SaleItem, isPercentage: boolean): number {
  return saleItemGross(item) - saleItemDiscountAmount(item, isPercentage);
}

/** Whether this line was rung up through a selling option. */
export function saleItemHasOption(item: SaleItem): boolean {
  return item.optionId !== null && item.optionPieces !== null && item.optionPieces > 0;
}

/** Whole sets on this line, or null with no option. quantity is always pieces. */
export function saleItemOptionSets(item: SaleItem): number | null {
  return saleItemHasOption(item) ? Math.floor(item.quantity / (item.optionPieces as number)) : null;
}

/** How much the +/- buttons move this line. A "By 3" line steps 3 -> 6. */
export function saleItemQuantityStep(item: SaleItem): number {
  return saleItemHasOption(item) ? (item.optionPieces as number) : 1;
}

/** Name for display, with the option label appended when there is one —
 * e.g. "Pulley Ball · By 3". Falls back to the bare name with no option.
 * Centralised here so every render site (Receipt, SaleDetailPage,
 * OrderSummary, SaleLines) constructs this string identically. */
export function saleItemDisplayName(item: SaleItem): string {
  return saleItemHasOption(item) ? `${item.name} · ${item.optionLabel}` : item.name;
}

/** Sets + total pieces caption for display, e.g. "By 3 × 2 (6 pcs)" for a
 * pcs product — null when there's no option or there's only one set (a
 * single set is fully said by saleItemDisplayName alone, so no extra
 * caption is shown). The unit suffix comes from item.unit itself (a plural,
 * unlike the per-piece rate suffix elsewhere), so a box-measured product
 * reads "By 3 × 2 (6 box)". */
export function saleItemOptionSetsCaption(item: SaleItem): string | null {
  const sets = saleItemOptionSets(item);
  if (sets === null || sets <= 1) return null;
  return `${item.optionLabel} × ${sets} (${item.quantity} ${item.unit})`;
}
