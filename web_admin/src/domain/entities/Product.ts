// Mirror of lib/domain/entities/product_entity.dart.
import type { SellingOption } from './SellingOption';

export interface Product {
  id: string;
  sku: string;
  name: string;
  costCode: string;
  cost: number;
  price: number;
  quantity: number;
  reorderLevel: number;
  unit: string;
  supplierId: string | null;
  supplierName: string | null;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date | null;
  createdBy: string | null;
  updatedBy: string | null;
  createdByName: string | null;
  updatedByName: string | null;
  searchKeywords: string[];
  baseSku: string | null;
  variationNumber: number | null;
  barcodes: string[];
  sellingOptions: SellingOption[];
  category: string | null;
  imageUrl: string | null;
  notes: string | null;
}

export const StockStatus = {
  inStock: 'inStock',
  lowStock: 'lowStock',
  outOfStock: 'outOfStock',
} as const;

export type StockStatus = (typeof StockStatus)[keyof typeof StockStatus];

export function getStockStatus(p: Product): StockStatus {
  if (p.quantity <= 0) return StockStatus.outOfStock;
  if (p.quantity <= p.reorderLevel) return StockStatus.lowStock;
  return StockStatus.inStock;
}

/** Whether the POS must show the option picker for this product. */
export function productHasSellingOptions(p: Product): boolean {
  return p.sellingOptions.length > 0;
}
