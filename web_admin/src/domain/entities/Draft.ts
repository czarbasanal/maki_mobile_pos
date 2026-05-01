// Mirror of lib/domain/entities/draft_entity.dart.
import type { DiscountType } from '../enums';
import type { SaleItem } from './SaleItem';

export interface Draft {
  id: string;
  name: string;
  items: SaleItem[];
  discountType: DiscountType;
  createdBy: string;
  createdByName: string;
  createdAt: Date;
  updatedAt: Date | null;
  updatedBy: string | null;
  isConverted: boolean;
  convertedToSaleId: string | null;
  convertedAt: Date | null;
  notes: string | null;
}
