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
