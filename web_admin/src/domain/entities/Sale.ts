// Mirror of lib/domain/entities/sale_entity.dart. Sale items live in the
// `sales/{id}/items` subcollection and are loaded separately.

import { DiscountType, type PaymentMethod, SaleStatus } from '../enums';
import {
  saleItemDiscountAmount,
  saleItemGross,
  saleItemNet,
  saleItemTotalCost,
  type SaleItem,
} from './SaleItem';

export interface Sale {
  id: string;
  saleNumber: string;
  items: SaleItem[];
  discountType: DiscountType;
  paymentMethod: PaymentMethod;
  amountReceived: number;
  changeGiven: number;
  status: SaleStatus;
  cashierId: string;
  cashierName: string;
  createdAt: Date;
  updatedAt: Date | null;
  draftId: string | null;
  notes: string | null;
  voidedAt: Date | null;
  voidedBy: string | null;
  voidedByName: string | null;
  voidReason: string | null;
}

// Computed helpers — Dart entity getters re-expressed as pure functions so
// the data layer can stay free of method-on-interface boilerplate.

export function saleIsPercentageDiscount(sale: Sale): boolean {
  return sale.discountType === DiscountType.percentage;
}

export function saleTotalItemCount(sale: Sale): number {
  return sale.items.reduce((sum, item) => sum + item.quantity, 0);
}

export function saleSubtotal(sale: Sale): number {
  return sale.items.reduce((sum, item) => sum + saleItemGross(item), 0);
}

export function saleTotalDiscount(sale: Sale): number {
  const isPercentage = saleIsPercentageDiscount(sale);
  return sale.items.reduce(
    (sum, item) => sum + saleItemDiscountAmount(item, isPercentage),
    0,
  );
}

export function saleGrandTotal(sale: Sale): number {
  return saleSubtotal(sale) - saleTotalDiscount(sale);
}

export function saleTotalCost(sale: Sale): number {
  return sale.items.reduce((sum, item) => sum + saleItemTotalCost(item), 0);
}

export function saleNetAmount(sale: Sale): number {
  const isPercentage = saleIsPercentageDiscount(sale);
  return sale.items.reduce((sum, item) => sum + saleItemNet(item, isPercentage), 0);
}

export function saleTotalProfit(sale: Sale): number {
  return saleGrandTotal(sale) - saleTotalCost(sale);
}

export function saleIsVoided(sale: Sale): boolean {
  return sale.status === SaleStatus.voided;
}
