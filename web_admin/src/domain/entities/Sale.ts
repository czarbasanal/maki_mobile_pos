// Mirror of lib/domain/entities/sale_entity.dart. Sale items live in the
// `sales/{id}/items` subcollection and are loaded separately.

import { DiscountType, type PaymentMethod, SaleStatus } from '../enums';
import type { LaborLine } from './LaborLine';
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
  laborLines: LaborLine[];
  mechanicId: string | null;
  mechanicName: string | null;
  tenders: Partial<Record<PaymentMethod, number>>;
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

// ==================== LABOR-AWARE MONEY MATH ====================
// Mirrors the Dart contract: grandTotal = partsRevenue + laborRevenue, where
// labor is full price (never discounted) and zero cost.

export function salePartsSubtotal(sale: Sale): number {
  return saleSubtotal(sale);
}

export function salePartsRevenue(sale: Sale): number {
  return salePartsSubtotal(sale) - saleTotalDiscount(sale);
}

export function saleLaborSubtotal(sale: Sale): number {
  return sale.laborLines.reduce((sum, line) => sum + line.fee, 0);
}

export function saleLaborRevenue(sale: Sale): number {
  return saleLaborSubtotal(sale);
}

export function saleGrandTotal(sale: Sale): number {
  return salePartsRevenue(sale) + saleLaborRevenue(sale);
}

export function salePartsProfit(sale: Sale): number {
  return salePartsRevenue(sale) - saleTotalCost(sale);
}

export function saleLaborProfit(sale: Sale): number {
  return saleLaborRevenue(sale);
}

/// Normalized payment breakdown. When the sale carries an explicit `tenders`
/// map (e.g. a mixed split), use it; otherwise attribute the whole
/// labor-inclusive grandTotal to the single payment method.
export function saleEffectiveTenders(
  sale: Sale,
): Partial<Record<PaymentMethod, number>> {
  if (Object.keys(sale.tenders).length > 0) return sale.tenders;
  return { [sale.paymentMethod]: saleGrandTotal(sale) };
}

export function saleTotalCost(sale: Sale): number {
  return sale.items.reduce((sum, item) => sum + saleItemTotalCost(item), 0);
}

export function saleNetAmount(sale: Sale): number {
  const isPercentage = saleIsPercentageDiscount(sale);
  return sale.items.reduce((sum, item) => sum + saleItemNet(item, isPercentage), 0);
}

export function saleTotalProfit(sale: Sale): number {
  return salePartsProfit(sale) + saleLaborProfit(sale);
}

export function saleIsVoided(sale: Sale): boolean {
  return sale.status === SaleStatus.voided;
}
