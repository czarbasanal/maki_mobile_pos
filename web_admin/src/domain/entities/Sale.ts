// Mirror of lib/domain/entities/sale_entity.dart. Sale items live in the
// `sales/{id}/items` subcollection and are loaded separately.

import type { DiscountType, PaymentMethod, SaleStatus } from '../enums';
import type { SaleItem } from './SaleItem';

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
