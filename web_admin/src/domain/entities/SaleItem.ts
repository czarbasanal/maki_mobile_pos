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
